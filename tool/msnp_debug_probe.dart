import 'dart:async';
import 'dart:io';

import 'package:wlm_project/network/msnp_client.dart';

Future<void> main(List<String> args) async {
  final email = Platform.environment['WLM_EMAIL'];
  final password = Platform.environment['WLM_PASSWORD'];

  if (email == null || email.isEmpty || password == null || password.isEmpty) {
    stdout.writeln('Usage: set env vars WLM_EMAIL and WLM_PASSWORD before running.');
    stdout.writeln('Optional env vars: WLM_HOST, WLM_PORT, WLM_DURATION_SECONDS');
    exitCode = 2;
    return;
  }

  final host = Platform.environment['WLM_HOST'] ?? '31.97.100.150';
  final port = int.tryParse(Platform.environment['WLM_PORT'] ?? '1864') ?? 1864;
  final durationSeconds =
      int.tryParse(Platform.environment['WLM_DURATION_SECONDS'] ?? '90') ?? 90;

  final client = MsnpClient();
  final start = DateTime.now();

  stdout.writeln('[Probe] Starting MSNP probe for $email at $host:$port');
  stdout.writeln('[Probe] Duration: ${durationSeconds}s');

  final statusSub = client.status.listen((status) {
    stdout.writeln('[Probe][Status] $status');
  });

  final eventSub = client.events.listen((event) {
    final from = event.from ?? '-';
    final body = (event.body ?? '').replaceAll('\n', ' ').replaceAll('\r', ' ');
    final shortBody = body.length > 180 ? '${body.substring(0, 180)}...' : body;
    stdout.writeln('[Probe][Event] ${event.command} type=${event.type} from=$from body=$shortBody');
  });

  try {
    await client.connect(
      email: email,
      password: password,
      passportTicket: '',
      host: host,
      port: port,
    );

    final ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      final elapsed = DateTime.now().difference(start).inSeconds;
      final snapshot = client.contactSnapshot;
      stdout.writeln('[Probe][Snapshot][$elapsed s] contacts=${snapshot.length}');
      for (final c in snapshot.take(10)) {
        stdout.writeln(
          '  - ${c.email} (${c.displayName}) ${c.status} '
          'psm=${c.personalMessage ?? '-'} media=${c.nowPlaying ?? '-'} '
          'msnobj=${c.avatarMsnObject == null ? 'no' : 'yes'}',
        );
      }
    });

    await Future<void>.delayed(Duration(seconds: durationSeconds));
    ticker.cancel();
  } catch (error, stackTrace) {
    stdout.writeln('[Probe][Error] $error');
    stdout.writeln(stackTrace.toString());
    exitCode = 1;
  } finally {
    await client.disconnect();
    await statusSub.cancel();
    await eventSub.cancel();
    client.dispose();
  }

  stdout.writeln('[Probe] Finished.');
}
