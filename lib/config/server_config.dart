class ServerConfig {
  // ── Notification Server (NS) ──────────────────────────────────────────
  static const String host = 'ms.msgrsvcs.ctsrv.gay';
  static const int port = 1864;

  // ── Authentication ────────────────────────────────────────────────────
  static const String authHost = 'ctas.login.ugnet.gay';
  static const int authPort = 443;
  static const String authPath = '/RST.srf';

  // ── Address Book / Contacts (ABCH) ────────────────────────────────────
  static const String abchHost = 'ctsvcs.addressbook.ugnet.gay';
  static const int abchPort = 443;
  static const String abchPath = '/abservice/abservice.asmx';

  // ── Offline Instant Messages (OIM) ────────────────────────────────────
  static const String oimHost = 'cts.storage.ugnet.gay';
  static const int oimPort = 443;
  static const String oimStorePath = '/OimWS/oim.asmx';
  static const String oimRetrievePath = '/rsi/rsi.asmx';

  // ── Storage / Profiles ────────────────────────────────────────────────
  static const String storageHost = 'cts.storage.ugnet.gay';

  // ── Dev helpers ───────────────────────────────────────────────────────
  static const String devPrefillEmail = '';
  static const String devPrefillPassword = '';

  // ── Timeouts ──────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration authTimeout = Duration(seconds: 10);
  static const Duration keepAlivePingInterval = Duration(seconds: 30);

  static Uri authUri({String? hostOverride}) {
    return Uri(
      scheme: 'https',
      host: hostOverride ?? authHost,
      port: authPort,
      path: authPath,
    );
  }

  static Uri abchUri({String? hostOverride}) {
    return Uri(
      scheme: 'https',
      host: hostOverride ?? abchHost,
      port: abchPort,
      path: abchPath,
    );
  }

  static Uri oimRetrieveUri({String? hostOverride}) {
    return Uri(
      scheme: 'https',
      host: hostOverride ?? oimHost,
      port: oimPort,
      path: oimRetrievePath,
    );
  }

  static Uri oimStoreUri({String? hostOverride}) {
    return Uri(
      scheme: 'https',
      host: hostOverride ?? oimHost,
      port: oimPort,
      path: oimStorePath,
    );
  }

  const ServerConfig._();
}
