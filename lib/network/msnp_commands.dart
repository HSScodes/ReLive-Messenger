class MsnpCommands {
  const MsnpCommands._();

  static const String msnQryTargetPrimary = 'PROD0090YUAUV{2B';
  static const String msnQryTargetLegacy = 'msmsgs@msnmsgr.com';
  static const String msnQryTargetAlt = 'PROD0119GSJUC\$18';
  static const String msnQryTargetWlm14 = 'PROD0120PW!CCV9@';
  static const String msnQryTargetMsnPecan = 'PROD0101{0RM?UBW';
  static const int wlm2009Capabilities = 2788999228;

  static const String msnProductId = 'PROD0090YUAUV{2B';

  static String ver(int trId) => 'VER $trId MSNP15 CVR0\r\n';

  static String cvr(int trId, String email) =>
      'CVR $trId 0x0409 winnt 10.0 i386 MSNMSGR 14.0.8117.0416 msmsgs $email\r\n';

  static String usrTwnI(int trId, String email) => 'USR $trId TWN I $email\r\n';

  static String usrTwnS(int trId, String ticket) =>
      'USR $trId TWN S $ticket\r\n';

  static String syn(int trId, int listRevision, {int groupRevision = 0}) =>
      'SYN $trId $listRevision $groupRevision\r\n';

  static String synLegacy(int trId, int listRevision) =>
      'SYN $trId $listRevision\r\n';

  static String synBare(int trId) => 'SYN $trId\r\n';

  static String gtc(int trId, String mode) => 'GTC $trId $mode\r\n';

  static String blp(int trId, String mode) => 'BLP $trId $mode\r\n';

  static String qryHeader(int trId, String productId, int payloadLength) =>
      'QRY $trId $productId $payloadLength\r\n';

  static String uux(int trId, String payload) {
    final length = payload.codeUnits.length;
    return 'UUX $trId $length\r\n$payload';
  }

  static String adl(int trId, String payload) {
    final length = payload.codeUnits.length;
    return 'ADL $trId $length\r\n$payload';
  }

  static String adlEmpty(int trId) => 'ADL $trId 0\r\n';

  static String rml(int trId, String payload) {
    final length = payload.codeUnits.length;
    return 'RML $trId $length\r\n$payload';
  }

  static String chg(
    int trId,
    String presenceCode, {
    int? capabilities,
    String? msnObject,
  }) {
    final buf = StringBuffer('CHG $trId $presenceCode');
    if (capabilities != null) {
      buf.write(' $capabilities');
    }
    if (msnObject != null && msnObject.isNotEmpty) {
      buf.write(' $msnObject');
    }
    buf.write('\r\n');
    return buf.toString();
  }

  static String png() => 'PNG\r\n';

  static String out() => 'OUT\r\n';

  /// PRP MFN — set the user's display (friendly) name on the server.
  static String prpMfn(int trId, String encodedName) =>
      'PRP $trId MFN $encodedName\r\n';

  /// CAL — invite a contact into the current switchboard session.
  static String cal(int trId, String email) => 'CAL $trId $email\r\n';
}
