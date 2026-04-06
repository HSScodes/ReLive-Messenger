import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/message.dart';

class ChatHistoryService {
  Future<List<Message>> loadMessages() async {
    try {
      final file = await _historyFile();
      if (!file.existsSync()) {
        return const <Message>[];
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const <Message>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <Message>[];
      }

      final messages = <Message>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final from = (item['from'] ?? '').toString();
        final to = (item['to'] ?? '').toString();
        final body = (item['body'] ?? '').toString();
        final timestampRaw = (item['timestamp'] ?? '').toString();
        final timestamp = DateTime.tryParse(timestampRaw);
        if (from.isEmpty || to.isEmpty || body.isEmpty || timestamp == null) {
          continue;
        }

        messages.add(
          Message(
            from: from,
            to: to,
            body: body,
            timestamp: timestamp,
            isNudge: item['isNudge'] == true,
            isTyping: item['isTyping'] == true,
          ),
        );
      }

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    } catch (_) {
      return const <Message>[];
    }
  }

  Future<void> saveMessages(List<Message> messages) async {
    try {
      final file = await _historyFile();
      final payload = messages
          .map(
            (m) => <String, dynamic>{
              'from': m.from,
              'to': m.to,
              'body': m.body,
              'timestamp': m.timestamp.toIso8601String(),
              'isNudge': m.isNudge,
              'isTyping': m.isTyping,
            },
          )
          .toList(growable: false);
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {
      // Ignore history persistence failures to keep chat flow resilient.
    }
  }

  Future<File> _historyFile() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}wlm_history');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    return File('${dir.path}${Platform.pathSeparator}messages.json');
  }
}
