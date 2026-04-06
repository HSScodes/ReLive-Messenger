import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String _listenHost = '127.0.0.1';
const int _listenPort = 18640;
const String _targetHost = '31.97.100.150';
const int _targetPort = 1864;

Future<void> main() async {
  final server = await ServerSocket.bind(_listenHost, _listenPort);
  stdout.writeln(
    '[SNIFFER] Listening on $_listenHost:$_listenPort -> forwarding to $_targetHost:$_targetPort',
  );

  await for (final localClient in server) {
    unawaited(_handleClient(localClient));
  }
}

Future<void> _handleClient(Socket localClient) async {
  final localAddr = '${localClient.remoteAddress.address}:${localClient.remotePort}';
  stdout.writeln('[SNIFFER] Local client connected: $localAddr');

  Socket remoteServer;
  try {
    remoteServer = await Socket.connect(_targetHost, _targetPort);
  } catch (error) {
    stdout.writeln('[SNIFFER] Failed to connect to remote server: $error');
    await localClient.close();
    return;
  }

  stdout.writeln('[SNIFFER] Remote server connected for $localAddr');

  final toServerLogger = _LineLogger('[WLM -> SERVER]');
  final toClientLogger = _LineLogger('[SERVER -> WLM]');

  final subs = <StreamSubscription<List<int>>>[];

  subs.add(
    localClient.listen(
      (bytes) {
        toServerLogger.addBytes(bytes);
        remoteServer.add(bytes);
      },
      onError: (Object error, StackTrace stackTrace) {
        stdout.writeln('[SNIFFER] Local client error: $error');
      },
      onDone: () async {
        toServerLogger.flush();
        try {
          await remoteServer.flush();
        } catch (_) {}
        await remoteServer.close();
      },
      cancelOnError: false,
    ),
  );

  subs.add(
    remoteServer.listen(
      (bytes) {
        toClientLogger.addBytes(bytes);
        localClient.add(bytes);
      },
      onError: (Object error, StackTrace stackTrace) {
        stdout.writeln('[SNIFFER] Remote server error: $error');
      },
      onDone: () async {
        toClientLogger.flush();
        try {
          await localClient.flush();
        } catch (_) {}
        await localClient.close();
      },
      cancelOnError: false,
    ),
  );

  await Future.wait(subs.map((s) => s.asFuture<void>()));

  for (final sub in subs) {
    await sub.cancel();
  }

  stdout.writeln('[SNIFFER] Connection closed: $localAddr');
}

class _LineLogger {
  _LineLogger(this.prefix);

  final String prefix;
  final StringBuffer _buffer = StringBuffer();

  void addBytes(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    _buffer.write(text);
    _emitCompleteLines();
  }

  void flush() {
    final remaining = _buffer.toString();
    if (remaining.isNotEmpty) {
      stdout.writeln('$prefix $remaining');
    }
    _buffer.clear();
  }

  void _emitCompleteLines() {
    var content = _buffer.toString();
    final lines = content.split(RegExp(r'\r\n|\n|\r'));

    final endsWithLineBreak = content.endsWith('\n') || content.endsWith('\r');
    final completeCount = endsWithLineBreak ? lines.length : lines.length - 1;

    if (completeCount <= 0) {
      return;
    }

    for (var i = 0; i < completeCount; i += 1) {
      stdout.writeln('$prefix ${lines[i]}');
    }

    final trailing = endsWithLineBreak ? '' : lines.last;
    _buffer
      ..clear()
      ..write(trailing);
  }
}
