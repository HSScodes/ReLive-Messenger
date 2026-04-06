import '../utils/presence_status.dart';

enum MsnpEventType {
  raw,
  handshake,
  message,
  typing,
  nudge,
  presence,
  contact,
  system,
}

class MsnpEvent {
  const MsnpEvent({
    required this.type,
    required this.command,
    this.from,
    this.to,
    this.body,
    this.presence,
    this.raw,
  });

  final MsnpEventType type;
  final String command;
  final String? from;
  final String? to;
  final String? body;
  final PresenceStatus? presence;
  final String? raw;
}

class MsnpParser {
  const MsnpParser._();

  static final RegExp _emailRegex = RegExp(
    r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
    caseSensitive: false,
  );
  static final RegExp _nTokenRegex = RegExp(r'\bN=([^\s;\r\n]+)', caseSensitive: false);

  static MsnpEvent parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return const MsnpEvent(type: MsnpEventType.raw, command: 'EMPTY');
    }

    final parts = _partsWithoutMsnObj(trimmed);
    final command = parts.first.toUpperCase();

    switch (command) {
      case 'VER':
      case 'CVR':
      case 'USR':
      case 'SYN':
      case 'CHG':
        return MsnpEvent(
          type: MsnpEventType.handshake,
          command: command,
          raw: trimmed,
        );
      case 'NLN':
      case 'ILN':
        return MsnpEvent(
          type: MsnpEventType.presence,
          command: command,
          from: _presenceEmail(parts),
          presence: _presenceStatus(parts),
          body: _presenceDisplayName(parts),
          raw: trimmed,
        );
      case 'FLN':
        final email = parts.length > 1 ? parts[1].trim().toLowerCase() : null;
        return MsnpEvent(
          type: MsnpEventType.presence,
          command: command,
          from: email,
          presence: PresenceStatus.appearOffline,
          raw: trimmed,
        );
      case 'LST':
        final email = _listEntryValue(parts, 'N=');
        final friendlyName = _listEntryValue(parts, 'F=');
        return MsnpEvent(
          type: MsnpEventType.contact,
          command: command,
          from: email,
          body: friendlyName,
          raw: trimmed,
        );
      case 'MSG':
        return MsnpEvent(type: MsnpEventType.system, command: command, raw: trimmed);
      default:
        return MsnpEvent(type: MsnpEventType.raw, command: command, raw: trimmed);
    }
  }

  static MsnpEvent parseMsgPayload({
    required String from,
    required String to,
    required String payload,
  }) {
    final parsed = _splitHeadersAndBody(payload);
    final contentType = (parsed.headers['content-type'] ?? '').toLowerCase();
    final typingUser = parsed.headers['typinguser'];
    if (contentType.contains('text/x-msnmsgr-datacast') &&
        parsed.headers['id']?.trim() == '1') {
      return MsnpEvent(
        type: MsnpEventType.nudge,
        command: 'MSG',
        from: from,
        to: to,
        body: 'Nudge',
      );
    }

    if (contentType.contains('text/x-msmsgscontrol') && typingUser != null && typingUser.isNotEmpty) {
      return MsnpEvent(
        type: MsnpEventType.typing,
        command: 'MSG',
        from: from,
        to: to,
        body: 'typing',
      );
    }

    if (!contentType.contains('text/plain')) {
      return MsnpEvent(
        type: MsnpEventType.system,
        command: 'MSG',
        from: from,
        to: to,
        raw: payload,
      );
    }

    final messageBody = parsed.body.trim();
    return MsnpEvent(
      type: MsnpEventType.message,
      command: 'MSG',
      from: from,
      to: to,
      body: messageBody.isEmpty ? payload.trim() : messageBody,
    );
  }

  static _ParsedMsgPayload _splitHeadersAndBody(String payload) {
    final separators = <String>['\r\n\r\n', '\n\n'];
    var splitIndex = -1;
    var separatorLength = 0;
    for (final separator in separators) {
      final idx = payload.indexOf(separator);
      if (idx != -1) {
        splitIndex = idx;
        separatorLength = separator.length;
        break;
      }
    }

    final headerText = splitIndex == -1 ? payload : payload.substring(0, splitIndex);
    final body = splitIndex == -1 ? '' : payload.substring(splitIndex + separatorLength);
    final headers = <String, String>{};
    for (final rawLine in headerText.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      final colon = line.indexOf(':');
      if (colon <= 0) {
        continue;
      }
      final key = line.substring(0, colon).trim().toLowerCase();
      final value = line.substring(colon + 1).trim();
      headers[key] = value;
    }

    return _ParsedMsgPayload(headers: headers, body: body);
  }

  static List<String> extractContactsFromSystemPayload(String payload) {
    final contacts = <String>{};

    final matches = _emailRegex.allMatches(payload);
    for (final match in matches) {
      final email = (match.group(0) ?? '').trim().toLowerCase();
      if (email.isNotEmpty) {
        contacts.add(email);
      }
    }

    final nMatches = _nTokenRegex.allMatches(payload);
    for (final match in nMatches) {
      final raw = (match.group(1) ?? '').trim();
      if (raw.isEmpty) {
        continue;
      }
      final decoded = Uri.decodeComponent(raw.replaceAll('+', ' ')).toLowerCase();
      if (_emailRegex.hasMatch(decoded)) {
        contacts.add(decoded);
      }
    }

    return contacts.toList(growable: false);
  }

  static String? _presenceEmail(List<String> parts) {
    if (parts.isEmpty) {
      return null;
    }

    final command = parts.first.toUpperCase();
    if (command == 'ILN') {
      // ILN <trId> <status> <email> <networkId> <nick> <clientId>
      return parts.length > 3 ? parts[3] : null;
    }
    if (command == 'NLN') {
      // NLN <status> <email> <networkId> <nick> <clientId>
      return parts.length > 2 ? parts[2] : null;
    }
    return null;
  }

  static PresenceStatus? _presenceStatus(List<String> parts) {
    if (parts.isEmpty) {
      return null;
    }

    final command = parts.first.toUpperCase();
    if (command == 'NLN') {
      return parts.length > 1 ? presenceFromMsnp(parts[1]) : null;
    }
    if (command == 'ILN') {
      return parts.length > 2 ? presenceFromMsnp(parts[2]) : null;
    }
    return null;
  }

  static String? _presenceDisplayName(List<String> parts) {
    if (parts.isEmpty) {
      return null;
    }

    final command = parts.first.toUpperCase();
    String? encoded;

    if (command == 'ILN' && parts.length > 5) {
      // ILN <trId> <status> <email> <networkId> <nick> <clientId>
      encoded = parts[5];
    }
    if (command == 'NLN' && parts.length > 4) {
      // NLN <status> <email> <networkId> <nick> <clientId>
      encoded = parts[4];
    }

    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    final decoded = Uri.decodeComponent(encoded.replaceAll('+', ' ')).trim();
    if (decoded.isEmpty || decoded == '1') {
      return null;
    }
    return decoded;
  }

  static List<String> _partsWithoutMsnObj(String line) {
    final objIndex = line.indexOf('%3Cmsnobj');
    final prefix = objIndex == -1 ? line : line.substring(0, objIndex).trimRight();
    return prefix.split(' ');
  }

  static String? _listEntryValue(List<String> parts, String prefix) {
    for (final part in parts) {
      if (!part.startsWith(prefix) || part.length <= prefix.length) {
        continue;
      }
      final value = part.substring(prefix.length);
      return Uri.decodeComponent(value.replaceAll('+', ' '));
    }
    return null;
  }
}

class _ParsedMsgPayload {
  const _ParsedMsgPayload({
    required this.headers,
    required this.body,
  });

  final Map<String, String> headers;
  final String body;
}
