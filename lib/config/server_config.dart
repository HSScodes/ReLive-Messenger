class ServerConfig {
  static const String host = '31.97.100.150';
  static const int port = 1864;
  static const int authPort = 80;
  static const String authPath = '/RST.srf';
  static const int abchPort = 80;
  static const String abchPath = '/abservice/abservice.asmx';
  static const String devPrefillEmail = 'henrique.2000@live.com.pt';
  static const String devPrefillPassword = 'Henrique00';
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration authTimeout = Duration(seconds: 10);
  static const Duration keepAlivePingInterval = Duration(seconds: 30);

  static Uri authUri({String? hostOverride}) {
    return Uri(
      scheme: 'http',
      host: hostOverride ?? host,
      port: authPort,
      path: authPath,
    );
  }

  const ServerConfig._();
}
