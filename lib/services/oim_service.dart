// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../config/server_config.dart';
import '../utils/challenge_utils.dart';

/// Parsed OIM (Offline Instant Message) header from server notification.
class OimHeader {
  const OimHeader({
    required this.messageId,
    required this.senderEmail,
    required this.senderName,
    required this.receivedTime,
    required this.size,
  });

  final String messageId;
  final String senderEmail;
  final String senderName;
  final DateTime receivedTime;
  final int size;
}

/// A fully retrieved OIM message.
class OimMessage {
  const OimMessage({
    required this.senderEmail,
    required this.senderName,
    required this.body,
    required this.receivedTime,
  });

  final String senderEmail;
  final String senderName;
  final String body;
  final DateTime receivedTime;
}

class OimService {
  // ── OIM lockkey state (cached across sends) ────────────────────────
  static const String _oimProductId = r'PROD0119GSJUC$18';
  static const String _oimProductKey = r'ILTXC!4IXB5FB*PX';
  static String? _cachedLockKey;

  /// Strip the `t=` prefix from a BinarySecurityToken if present.
  static String _stripTicketPrefix(String ticket) {
    if (ticket.startsWith('t=')) return ticket.substring(2);
    return ticket;
  }

  /// Parse the initial mail-data notification XML from the NS MSG payload.
  /// Returns OIM headers for any pending offline messages, or empty list.
  static List<OimHeader> parseMailDataNotification(String xml) {
    final headers = <OimHeader>[];

    // Don't trust the <O> count — CrossTalk may report 0 while still
    // including <M> blocks.  Always attempt to parse the entries.

    // Parse each <M> entry.
    final mBlocks = _extractAllBlocks(xml, 'M');
    for (final block in mBlocks) {
      final mailType = _extractTag(block, 'T');
      if (mailType != '11') continue; // 11 = OIM

      final messageId = _extractTag(block, 'I') ?? '';
      final senderEmail = _extractTag(block, 'E') ?? '';
      final senderName = _extractTag(block, 'N') ?? senderEmail;
      final rtStr = _extractTag(block, 'RT') ?? '';
      final sizeStr = _extractTag(block, 'SZ') ?? '0';

      if (messageId.isEmpty || senderEmail.isEmpty) continue;

      DateTime receivedTime;
      try {
        receivedTime = DateTime.parse(rtStr);
      } catch (_) {
        receivedTime = DateTime.now();
      }

      headers.add(
        OimHeader(
          messageId: messageId,
          senderEmail: senderEmail,
          senderName: _decodeOimName(senderName),
          receivedTime: receivedTime,
          size: int.tryParse(sizeStr) ?? 0,
        ),
      );
    }
    return headers;
  }

  /// Retrieve a single OIM message body from the RSI SOAP endpoint.
  static Future<OimMessage?> getMessage({
    required String host,
    required String ticket,
    required OimHeader header,
    String? mspAuth,
    String? sid,
    void Function(String)? log,
  }) async {
    log?.call(
      'OIM GetMessage for ${header.messageId} from ${header.senderEmail}',
    );
    log?.call(
      'OIM GetMessage: ticket=${ticket.length} chars, '
      'mspAuth=${(mspAuth ?? '').length} chars',
    );

    final soapBody =
        '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Header>
    <PassportCookie xmlns="http://www.hotmail.msn.com/ws/2004/09/oim/rsi">
      <t>${_xmlEscape(_stripTicketPrefix(ticket))}</t>
      <p>${_xmlEscape(mspAuth ?? '')}</p>
    </PassportCookie>
  </soap:Header>
  <soap:Body>
    <GetMessage xmlns="http://www.hotmail.msn.com/ws/2004/09/oim/rsi">
      <messageId>${_xmlEscape(header.messageId)}</messageId>
      <alsoMarkAsRead>true</alsoMarkAsRead>
    </GetMessage>
  </soap:Body>
</soap:Envelope>''';

    log?.call(
      'OIM GetMessage envelope (first 600):\n'
      '${soapBody.length > 600 ? soapBody.substring(0, 600) : soapBody}',
    );

    try {
      final uri = Uri(
        scheme: 'https',
        host: host,
        port: ServerConfig.oimPort,
        path: ServerConfig.oimRetrievePath,
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'text/xml; charset=utf-8');
      request.headers.set(
        'SOAPAction',
        '"http://www.hotmail.msn.com/ws/2004/09/oim/rsi/GetMessage"',
      );
      request.headers.set('User-Agent', 'MSMSGS');
      request.add(utf8.encode(soapBody));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: false);

      if (response.statusCode != 200) {
        log?.call(
          'OIM GetMessage failed: HTTP ${response.statusCode}\n'
          '${body.length > 500 ? body.substring(0, 500) : body}',
        );
        return null;
      }

      // Extract the message content from the SOAP response.
      // The response contains GetMessageResult which has the full message
      // encoded in a MIME-like format with base64 body.
      final resultContent = _extractTag(body, 'GetMessageResult');
      if (resultContent == null || resultContent.isEmpty) {
        log?.call('OIM GetMessage: empty result');
        return null;
      }

      final messageBody = _extractOimBodyFromMime(resultContent);
      log?.call(
        'OIM GetMessage success from ${header.senderEmail}: $messageBody',
      );

      return OimMessage(
        senderEmail: header.senderEmail,
        senderName: header.senderName,
        body: messageBody,
        receivedTime: header.receivedTime,
      );
    } catch (e) {
      log?.call('OIM GetMessage exception: $e');
      return null;
    }
  }

  /// Delete OIM messages from the server after retrieval.
  static Future<bool> deleteMessages({
    required String host,
    required String ticket,
    required List<String> messageIds,
    String? mspAuth,
    void Function(String)? log,
  }) async {
    if (messageIds.isEmpty) return true;

    final idsXml = messageIds
        .map((id) => '<messageId>${_xmlEscape(id)}</messageId>')
        .join();

    final soapBody =
        '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Header>
    <PassportCookie xmlns="http://www.hotmail.msn.com/ws/2004/09/oim/rsi">
      <t>${_xmlEscape(_stripTicketPrefix(ticket))}</t>
      <p>${_xmlEscape(mspAuth ?? '')}</p>
    </PassportCookie>
  </soap:Header>
  <soap:Body>
    <DeleteMessages xmlns="http://www.hotmail.msn.com/ws/2004/09/oim/rsi">
      <messageIds>
        $idsXml
      </messageIds>
    </DeleteMessages>
  </soap:Body>
</soap:Envelope>''';

    try {
      final uri = Uri(
        scheme: 'https',
        host: host,
        port: ServerConfig.oimPort,
        path: ServerConfig.oimRetrievePath,
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'text/xml; charset=utf-8');
      request.headers.set(
        'SOAPAction',
        '"http://www.hotmail.msn.com/ws/2004/09/oim/rsi/DeleteMessages"',
      );
      request.headers.set('User-Agent', 'MSMSGS');
      request.add(utf8.encode(soapBody));
      final response = await request.close();
      await response.drain<void>();
      client.close(force: false);

      log?.call('OIM DeleteMessages: HTTP ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      log?.call('OIM DeleteMessages exception: $e');
      return false;
    }
  }

  /// Send an offline message to a contact via the OIM Store SOAP endpoint.
  ///
  /// Implements the LockKeyChallenge retry flow: on first attempt the lockkey
  /// may be empty; if the server responds with a `<LockKeyChallenge>` nonce
  /// we compute a lockkey from it using the OIM product pair and retry once.
  static Future<bool> sendMessage({
    required String host,
    required String ticket,
    required String senderEmail,
    required String senderName,
    required String recipientEmail,
    required String body,
    String? mspAuth,
    void Function(String)? log,
  }) async {
    log?.call('OIM Store2 → $recipientEmail: ${body.length} chars');

    // Base64-encode and MIME-wrap at 76 characters per line.
    final rawB64 = base64.encode(utf8.encode(body));
    final b64Body = _mimeWrapBase64(rawB64);

    // Build a run-id as a proper GUID.
    final runId = _randomGuid();

    // Build MIME content with actual CRLF bytes (matching reference impl).
    const crlf = '\r\n';
    final mimeContent =
        'MIME-Version: 1.0${crlf}Content-Type: text/plain; charset=UTF-8'
        '${crlf}Content-Transfer-Encoding: base64'
        '${crlf}X-OIM-Message-Type: OfflineMessage'
        '${crlf}X-OIM-Run-Id: {$runId}'
        '${crlf}X-OIM-Sequence-Num: 1$crlf$crlf$b64Body';

    // Attempt up to 2 times: first with cached (or empty) lockkey, then with
    // a freshly computed one if the server returns a LockKeyChallenge.
    for (var attempt = 0; attempt < 2; attempt++) {
      final lockKey = _cachedLockKey ?? '';

      final soapEnvelope =
          '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Header>
    <From xmlns="http://messenger.msn.com/ws/2004/09/oim/"
          memberName="${_xmlEscape(senderEmail)}"
          friendlyName="${_xmlEscape(_encodeOimName(senderName))}"
          xml:lang="en-US"
          proxy="MSNMSGR"
          msnpVer="MSNP15"
          buildVer="14.0.8117.0416" />
    <To xmlns="http://messenger.msn.com/ws/2004/09/oim/"
        memberName="${_xmlEscape(recipientEmail)}" />
    <Ticket xmlns="http://messenger.msn.com/ws/2004/09/oim/"
            passport="${_xmlEscape(ticket)}"
            appid="$_oimProductId"
            lockkey="$lockKey" />
    <Sequence xmlns="http://schemas.xmlsoap.org/ws/2003/03/rm">
      <Identifier xmlns="http://schemas.xmlsoap.org/ws/2002/07/utility">http://messenger.msn.com</Identifier>
      <MessageNumber>1</MessageNumber>
    </Sequence>
  </soap:Header>
  <soap:Body>
    <MessageType xmlns="http://messenger.msn.com/ws/2004/09/oim/">text</MessageType>
    <Content xmlns="http://messenger.msn.com/ws/2004/09/oim/">$mimeContent</Content>
  </soap:Body>
</soap:Envelope>''';

      log?.call(
        'OIM Store2 envelope (first 800):\n'
        '${soapEnvelope.length > 800 ? soapEnvelope.substring(0, 800) : soapEnvelope}',
      );

      try {
        final uri = Uri(
          scheme: 'https',
          host: host,
          port: ServerConfig.oimPort,
          path: ServerConfig.oimStorePath,
        );

        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 10);
        final request = await client.postUrl(uri);
        request.headers.set('Content-Type', 'text/xml; charset=utf-8');
        request.headers.set(
          'SOAPAction',
          '"http://messenger.live.com/ws/2006/09/oim/Store2"',
        );
        request.headers.set('User-Agent', 'MSMSGS');
        request.add(utf8.encode(soapEnvelope));
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();
        client.close(force: false);

        if (response.statusCode == 200) {
          log?.call('OIM Store2 success → $recipientEmail');
          return true;
        }

        // Check for LockKeyChallenge in the SOAP fault — retry with computed
        // lockkey using the OIM product pair (MSNP11 algorithm).
        final challengeNonce = _extractLockKeyChallenge(responseBody);
        if (challengeNonce != null && attempt == 0) {
          log?.call('OIM Store2: LockKeyChallenge received, computing lockkey');
          _cachedLockKey = computeMsnp11Challenge(
            challenge: challengeNonce,
            productId: _oimProductId,
            productKey: _oimProductKey,
          );
          continue; // retry with the new lockkey
        }

        log?.call(
          'OIM Store2 failed: HTTP ${response.statusCode}\n$responseBody',
        );
        return false;
      } catch (e) {
        log?.call('OIM Store2 exception: $e');
        return false;
      }
    }
    return false;
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Extract the LockKeyChallenge nonce from a SOAP fault response body.
  /// Returns `null` if no challenge is present.
  static String? _extractLockKeyChallenge(String responseBody) {
    // The challenge sits inside <LockKeyChallenge ...>nonce</LockKeyChallenge>
    final startTag = responseBody.indexOf('<LockKeyChallenge');
    if (startTag == -1) return null;
    final gt = responseBody.indexOf('>', startTag);
    if (gt == -1) return null;
    final lt = responseBody.indexOf('<', gt + 1);
    if (lt == -1) return null;
    final nonce = responseBody.substring(gt + 1, lt).trim();
    return nonce.isEmpty ? null : nonce;
  }

  /// MIME-wrap a raw base64 string at 76 characters per line (RFC 2045).
  static String _mimeWrapBase64(String raw) {
    final buf = StringBuffer();
    for (var i = 0; i < raw.length; i += 76) {
      final end = (i + 76 < raw.length) ? i + 76 : raw.length;
      buf.write(raw.substring(i, end));
      if (end < raw.length) buf.write('\r\n');
    }
    return buf.toString();
  }

  /// Generate a random GUID string (8-4-4-4-12 hex format).
  static String _randomGuid() {
    final r = Random();
    String hex(int len) =>
        List.generate(len, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-${hex(4)}-${hex(4)}-${hex(12)}';
  }

  static String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static String? _extractTag(String xml, String tag) {
    final open = '<$tag>';
    final close = '</$tag>';
    final start = xml.indexOf(open);
    if (start == -1) return null;
    final end = xml.indexOf(close, start);
    if (end == -1) return null;
    return xml.substring(start + open.length, end).trim();
  }

  static List<String> _extractAllBlocks(String xml, String tag) {
    final blocks = <String>[];
    final open = '<$tag>';
    final close = '</$tag>';
    var searchFrom = 0;
    while (true) {
      final start = xml.indexOf(open, searchFrom);
      if (start == -1) break;
      final end = xml.indexOf(close, start);
      if (end == -1) break;
      blocks.add(xml.substring(start + open.length, end));
      searchFrom = end + close.length;
    }
    return blocks;
  }

  /// Decode a display name that may be base64-encoded (OIM format uses
  /// =?utf-8?B?...?= encoding).
  static String _decodeOimName(String name) {
    final match = RegExp(
      r'=\?utf-8\?B\?(.+?)\?=',
      caseSensitive: false,
    ).firstMatch(name);
    if (match != null) {
      try {
        return utf8.decode(base64.decode(match.group(1)!));
      } catch (_) {}
    }
    return name;
  }

  /// Encode a display name in =?utf-8?B?...?= format for OIM Store.
  static String _encodeOimName(String name) {
    return '=?utf-8?B?${base64.encode(utf8.encode(name))}?=';
  }

  /// Extract the plain-text body from the MIME-like OIM message result.
  /// The result typically has MIME headers followed by a base64 body.
  static String _extractOimBodyFromMime(String mimeContent) {
    // The content may be HTML-encoded in the SOAP response.
    var content = mimeContent
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");

    // Split headers from body at the double CRLF or double LF.
    // Check literal \r\n text first (OIM Content uses escaped CRLF),
    // then actual CRLF bytes, then bare LF.
    var splitIdx = content.indexOf(r'\r\n\r\n');
    int bodyStart;
    if (splitIdx != -1) {
      bodyStart = splitIdx + 8; // literal \r\n\r\n is 8 chars
    } else {
      splitIdx = content.indexOf('\r\n\r\n');
      if (splitIdx != -1) {
        bodyStart = splitIdx + 4;
      } else {
        splitIdx = content.indexOf('\n\n');
        if (splitIdx == -1) return content.trim();
        bodyStart = splitIdx + 2;
      }
    }

    final headers = content.substring(0, splitIdx).toLowerCase();
    var body = content.substring(bodyStart).trim();

    // If base64-encoded, decode it.
    if (headers.contains('base64')) {
      try {
        // Remove literal \r\n text and any whitespace/newlines from base64.
        final cleaned = body
            .replaceAll(r'\r\n', '')
            .replaceAll(RegExp(r'\s'), '');
        return utf8.decode(base64.decode(cleaned));
      } catch (_) {
        return body;
      }
    }

    return body;
  }
}
