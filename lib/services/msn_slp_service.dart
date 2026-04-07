import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class MsnSlpService {
  static const String displayPictureEufGuid =
      '{A4268EEC-FEC5-49E5-95C3-F126696BDBF6}';
  static const int displayPictureAppId = 1;
  static const int displayPictureSessionId = 1234;

  final Random _random = Random();

  P2pInviteResult buildDisplayPictureInviteBinary({
    required String contactEmail,
    required String myEmail,
    required String fullMsnObjectXml,
  }) {
    final branchId = '{${_newGuid()}}';
    final callId = '{${_newGuid()}}';
    final rawMsnObj = _normalizeMsnObjXml(fullMsnObjectXml);
    // Null-terminate the MSNObject XML before base64-encoding — WLM expects
    // the context to be a null-terminated UTF-8 string.
    final contextBytes = <int>[...utf8.encode(rawMsnObj), 0];
    final context = base64.encode(contextBytes);

    // Generate a random non-zero session ID for the SLP body.  The binary
    // P2P transport header uses SessionID=0 for all SLP control messages;
    // only data-transfer frames carry the negotiated non-zero session ID.
    final sessionId = _random.nextInt(0x7FFFFFFE) + 1; // 1 .. 0x7FFFFFFF

    final bodyText = 'EUF-GUID: $displayPictureEufGuid\r\n'
        'SessionID: $sessionId\r\n'
        'AppID: $displayPictureAppId\r\n'
        'Context: $context\r\n\r\n';
    final bodyLength = utf8.encode(bodyText).length;

    // CSeq: 0 for the initial INVITE (increments in subsequent transactions).
    // Build the SLP text.  The empty string at index 9 produces the mandatory
    // blank CRLF line that separates SLP headers from the body.
    final slpText = [
      'INVITE MSNMSGR:$contactEmail MSNSLP/1.0',
      'To: <msnmsgr:$contactEmail>',
      'From: <msnmsgr:$myEmail>',
      'Via: MSNSLP/1.0/TLP ;branch=$branchId',
      'CSeq: 0',
      'Call-ID: $callId',
      'Max-Forwards: 0',
      'Content-Type: application/x-msnmsgr-sessionreqbody',
      'Content-Length: $bodyLength',
      '',
      bodyText,
    ].join('\r\n');

    final baseId = _random.nextInt(0x7fffffff);
    // SessionID=0 in binary header for SLP control messages (not data frames).
    final p2pBytes = buildP2pPayload(0, baseId, 0, slpText);
    return P2pInviteResult(
      bytes: p2pBytes,
      callId: callId,
      branchId: branchId,
      sessionId: sessionId,
      baseId: baseId,
    );
  }

  /// Builds the SLP-level ACK text payload, wrapped in a P2P binary frame
  /// (Flags=0), ready to be prepended with MIME headers and sent via MSG.
  ///
  /// Must be sent after receiving the peer's MSNSLP/1.0 200 OK so that the
  /// peer knows we are ready to receive the data stream.
  List<int> buildSlpAckPacket({
    required String myEmail,
    required String peerEmail,
    required String callId,
    required String branchId,
    required int sessionId,
    required int baseId,
  }) {
    // Per MSNSLP spec the ACK body is empty (Content-Length: 0).
    // CSeq: 1 because this ACK follows the peer's 200 OK (which had CSeq: 1).
    final slpText = 'ACK MSNMSGR:$peerEmail MSNSLP/1.0\r\n'
        'To: <msnmsgr:$peerEmail>\r\n'
        'From: <msnmsgr:$myEmail>\r\n'
        'Via: MSNSLP/1.0/TLP ;branch=$branchId\r\n'
        'CSeq: 1\r\n'
        'Call-ID: $callId\r\n'
        'Max-Forwards: 0\r\n'
        'Content-Type: application/x-msnmsgr-sessionreqbody\r\n'
        'Content-Length: 0\r\n'
        '\r\n';

    // SessionID=0 in binary header — this is an SLP control message, not data.
    return buildP2pPayload(0, baseId, 0, slpText);
  }

  /// Builds a 48-byte P2P ACK packet (Flags = 0x08) with no body, wrapped in
  /// MIME headers suitable for sending via `MSG D` on the Switchboard.
  ///
  /// [incomingSessionId] / [incomingBaseId] are from the packet being ACKed.
  /// [ackedTotalSize] equals the [totalSize] field of the packet being ACKed
  /// (the full size of the acknowledged message, not just this fragment).
  List<int> buildAckBinary({
    required int incomingSessionId,
    required int incomingBaseId,
    required int ackedTotalSize,
  }) {
    // WLM mirrors the acknowledged message's TotalSize at both offset 16
    // (TotalDataSize of this ACK frame) and offset 40-47 (AckDataSize field).
    final ackBaseId = _random.nextInt(0x7fffffff);
    final header = ByteData(48);
    header.setUint32(0, 0, Endian.little);              // SessionID = 0
    header.setUint32(4, ackBaseId, Endian.little);      // BaseID (our local)
    header.setUint64(8, 0, Endian.little);              // Offset
    header.setUint64(16, ackedTotalSize, Endian.little);// TotalDataSize = acked
    header.setUint32(24, 0, Endian.little);             // MessageSize = 0
    header.setUint32(28, 0x02, Endian.little);          // Flags = ACK
    header.setUint32(32, incomingSessionId, Endian.little); // AckSessionID
    header.setUint32(36, incomingBaseId, Endian.little);    // AckBaseID
    // AckDataSize is uint64; safe to store size as lower 32 bits.
    header.setUint32(40, ackedTotalSize & 0xFFFFFFFF, Endian.little);
    header.setUint32(44, (ackedTotalSize >> 32) & 0xFFFFFFFF, Endian.little);

    final footer = ByteData(4);
    footer.setUint32(0, 0, Endian.big); // footer = 0 for ACK

    return <int>[
      ...header.buffer.asUint8List(),
      ...footer.buffer.asUint8List(),
    ];
  }

  /// Builds a P2P binary frame for SLP control messages (INVITE, BYE, ACK).
  /// [footer] is the application identifier appended after the SLP text:
  ///   0 = SLP control message, 1 = display picture (AppID 1).
  List<int> buildP2pPayload(
    int sessionId,
    int baseId,
    int flags,
    String slpText, {
    int footer = 0,
  }) {
    // Null-terminate the SLP text on the wire — MSNP P2P requires all SLP
    // payloads to end with \0.  But TotalDataSize / MessageSize in the binary
    // header use the string length WITHOUT the null terminator (matching
    // libpurple / Pidgin behavior).  The footer is NOT counted in sizes.
    final rawSlpBytes = utf8.encode(slpText);
    final slpBytes = [...rawSlpBytes, 0];
    final textLength = rawSlpBytes.length; // WITHOUT null

    final header = ByteData(48);
    header.setUint32(0, sessionId, Endian.little);
    header.setUint32(4, baseId, Endian.little);
    header.setUint64(8, 0, Endian.little);
    header.setUint64(16, textLength, Endian.little);
    header.setUint32(24, textLength, Endian.little);
    header.setUint32(28, flags, Endian.little);
    header.setUint32(32, 0, Endian.little);
    header.setUint32(36, 0, Endian.little);
    header.setUint64(40, 0, Endian.little);

    final footerBytes = ByteData(4);
    footerBytes.setUint32(0, footer, Endian.big);

    return <int>[
      ...header.buffer.asUint8List(),
      ...slpBytes,
      ...footerBytes.buffer.asUint8List(),
    ];
  }

  /// Builds a P2P binary data chunk (for avatar or file transfer data).
  List<int> buildP2pDataChunk({
    required int sessionId,
    required int baseId,
    required int offset,
    required int totalSize,
    required List<int> chunkData,
    int flags = 0x20,
    int footer = 1,
  }) {
    final header = ByteData(48);
    header.setUint32(0, sessionId, Endian.little);
    header.setUint32(4, baseId, Endian.little);
    header.setUint64(8, offset, Endian.little);         // Offset
    header.setUint64(16, totalSize, Endian.little);      // TotalDataSize
    header.setUint32(24, chunkData.length, Endian.little); // MessageSize
    header.setUint32(28, flags, Endian.little);           // Flags (0x20 = data)
    header.setUint32(32, 0, Endian.little);
    header.setUint32(36, 0, Endian.little);
    header.setUint64(40, 0, Endian.little);

    final footerBytes = ByteData(4);
    footerBytes.setUint32(0, footer, Endian.big);

    return <int>[
      ...header.buffer.asUint8List(),
      ...chunkData,
      ...footerBytes.buffer.asUint8List(),
    ];
  }

  /// Builds a P2P data-preparation packet.
  ///
  /// WLM 2009 expects this 4-byte "data-prep" frame between the 200 OK and
  /// the actual image/file data.  Without it the peer's P2P state machine
  /// never transitions to the data-receive state and eventually times out.
  ///
  /// Format observed in real WLM 2009 traffic:
  ///   SessionID = allocated session ID
  ///   Flags     = 0x00
  ///   MsgSize   = 4, TotalSize = 4
  ///   Body      = 4 bytes of 0x00
  ///   Footer    = AppID (1 = display picture, 2 = file transfer)
  List<int> buildDataPrepPacket({
    required int sessionId,
    required int baseId,
    int footer = 1,
  }) {
    final header = ByteData(48);
    header.setUint32(0, sessionId, Endian.little);
    header.setUint32(4, baseId, Endian.little);
    header.setUint64(8, 0, Endian.little);          // Offset = 0
    header.setUint64(16, 4, Endian.little);          // TotalDataSize = 4
    header.setUint32(24, 4, Endian.little);          // MessageSize = 4
    header.setUint32(28, 0, Endian.little);          // Flags = 0x00
    header.setUint32(32, 0, Endian.little);
    header.setUint32(36, 0, Endian.little);
    header.setUint64(40, 0, Endian.little);

    final body = Uint8List(4); // 4 zero bytes

    final footerBytes = ByteData(4);
    footerBytes.setUint32(0, footer, Endian.big);

    return <int>[
      ...header.buffer.asUint8List(),
      ...body,
      ...footerBytes.buffer.asUint8List(),
    ];
  }

  /// Builds a 200 OK transport response selecting SBBridge, wrapped in a P2P
  /// binary frame, in response to an incoming transreqbody INVITE from the peer.
  List<int> buildTransportResponse200({
    required String myEmail,
    required String peerEmail,
    required String branchId,
    required String callId,
    required int sessionId,
  }) {
    final bodyText = 'Bridge: SBBridge\r\n'
        'Listening: false\r\n'
        'Hashed-Nonce: {00000000-0000-0000-0000-000000000000}\r\n'
        'SessionID: $sessionId\r\n'
        'SChannelState: 0\r\n\r\n';
    final bodyLength = utf8.encode(bodyText).length;

    final slpText = [
      'MSNSLP/1.0 200 OK',
      'To: <msnmsgr:$peerEmail>',
      'From: <msnmsgr:$myEmail>',
      'Via: MSNSLP/1.0/TLP ;branch=$branchId',
      'CSeq: 1',
      'Call-ID: $callId',
      'Max-Forwards: 0',
      'Content-Type: application/x-msnmsgr-transrespbody',
      'Content-Length: $bodyLength',
      '',
      bodyText,
    ].join('\r\n');

    final baseId = _random.nextInt(0x7fffffff);
    return buildP2pPayload(0, baseId, 0, slpText);
  }

  bool isP2pPayloadBytes(List<int> payloadBytes) {
    final payload = ascii.decode(payloadBytes, allowInvalid: true);
    final contentType = _extractHeader(payload, 'Content-Type')?.toLowerCase() ?? '';
    if (contentType.contains('application/x-msnmsgrp2p')) {
      return true;
    }

    final marker = ascii.encode('MSNSLP/1.0');
    final markerIndex = _indexOfBytes(payloadBytes, marker);
    if (markerIndex != -1) {
      return true;
    }

    if (payloadBytes.length > 48) {
      final tail = ascii.decode(payloadBytes.sublist(48), allowInvalid: true);
      if (tail.contains('MSNSLP/1.0')) {
        return true;
      }
    }

    return false;
  }

  P2pInboundFrame? parseInboundP2pFrame(List<int> payloadBytes) {
    final split = _splitHeaderAndBodyBytes(payloadBytes);
    final p2pBytes = split.body;
    if (p2pBytes.length < 48) {
      return null;
    }

    final header = ByteData.sublistView(Uint8List.fromList(p2pBytes.sublist(0, 48)));
    final sessionId = header.getUint32(0, Endian.little);
    final baseId   = header.getUint32(4, Endian.little);
    final offset   = header.getUint64(8, Endian.little);
    final totalSize   = header.getUint64(16, Endian.little);
    final messageSize = header.getUint32(24, Endian.little);
    final flags       = header.getUint32(28, Endian.little);
    final ackSessionId = header.getUint32(32, Endian.little);
    final ackUniqueId  = header.getUint32(36, Endian.little);

    if (messageSize == 0) {
      return P2pInboundFrame(
        sessionId: sessionId,
        baseId: baseId,
        offset: offset,
        totalSize: totalSize,
        messageSize: messageSize,
        flags: flags,
        slpText: '',
        ackSessionId: ackSessionId,
        ackUniqueId: ackUniqueId,
      );
    }

    final availableBody = p2pBytes.length - 48;
    final wantedSize = messageSize > availableBody ? availableBody : messageSize;
    final slpBytes = wantedSize <= 0
        ? const <int>[]
        : p2pBytes.sublist(48, 48 + wantedSize);
    final slpText = utf8.decode(slpBytes, allowMalformed: true).replaceAll('\u0000', '').trim();

    return P2pInboundFrame(
      sessionId: sessionId,
      baseId: baseId,
      offset: offset,
      totalSize: totalSize,
      messageSize: messageSize,
      flags: flags,
      slpText: slpText,
      ackSessionId: ackSessionId,
      ackUniqueId: ackUniqueId,
    );
  }

  void handleInboundP2p({
    required String from,
    required List<int> payloadBytes,
  }) {
    final slpText = _extractSlpText(payloadBytes).trim();
    if (slpText.isEmpty) {
      return;
    }

    if (slpText.contains('MSNSLP/1.0 200 OK')) {
      print('[MSNSLP] 200 OK from $from');
      print('[MSNSLP] RAW:\n$slpText');
      return;
    }

    if (slpText.startsWith('INVITE MSNMSGR:')) {
      print('[MSNSLP] INVITE from $from');
      print('[MSNSLP] RAW:\n$slpText');
    }
  }

  String _extractSlpText(List<int> payloadBytes) {
    final split = _splitHeaderAndBodyBytes(payloadBytes);
    if (split.body.isNotEmpty) {
      if (split.body.length > 52) {
        final candidate = utf8.decode(
          split.body.sublist(48, split.body.length - 4),
          allowMalformed: true,
        );
        final idx = candidate.indexOf('MSNSLP/1.0');
        if (idx != -1) {
          return candidate.substring(idx);
        }
      }
      final direct = utf8.decode(split.body, allowMalformed: true);
      final directIdx = direct.indexOf('MSNSLP/1.0');
      if (directIdx != -1) {
        return direct.substring(directIdx);
      }
    }

    if (payloadBytes.length > 52) {
      final withP2pHeader = utf8.decode(
        payloadBytes.sublist(48, payloadBytes.length - 4),
        allowMalformed: true,
      );
      final idx = withP2pHeader.indexOf('MSNSLP/1.0');
      if (idx != -1) {
        return withP2pHeader.substring(idx);
      }
    }

    final full = utf8.decode(payloadBytes, allowMalformed: true);
    final fullIdx = full.indexOf('MSNSLP/1.0');
    if (fullIdx != -1) {
      return full.substring(fullIdx);
    }
    return '';
  }

  _HeaderBodySplitBytes _splitHeaderAndBodyBytes(List<int> payloadBytes) {
    final marker = <int>[13, 10, 13, 10];
    final idx = _indexOfBytes(payloadBytes, marker);
    if (idx == -1) {
      return _HeaderBodySplitBytes(headers: payloadBytes, body: const <int>[]);
    }
    return _HeaderBodySplitBytes(
      headers: payloadBytes.sublist(0, idx),
      body: payloadBytes.sublist(idx + marker.length),
    );
  }

  int _indexOfBytes(List<int> source, List<int> pattern) {
    if (pattern.isEmpty || source.length < pattern.length) {
      return -1;
    }
    for (var i = 0; i <= source.length - pattern.length; i += 1) {
      var ok = true;
      for (var j = 0; j < pattern.length; j += 1) {
        if (source[i + j] != pattern[j]) {
          ok = false;
          break;
        }
      }
      if (ok) {
        return i;
      }
    }
    return -1;
  }

  String _normalizeMsnObjXml(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) {
      return normalized;
    }

    for (var i = 0; i < 3; i += 1) {
      final decoded = Uri.decodeFull(normalized);
      if (decoded == normalized) {
        break;
      }
      normalized = decoded;
    }

    normalized = normalized
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return normalized;
  }

  String _newGuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    // Set version (4) and variant bits for a proper UUID v4.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();

    final b = bytes.map(hex).toList(growable: false);
    return '${b[0]}${b[1]}${b[2]}${b[3]}-'
        '${b[4]}${b[5]}-'
        '${b[6]}${b[7]}-'
        '${b[8]}${b[9]}-'
        '${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}';
  }

  _HeaderBodySplit _splitHeadersAndBody(String payload) {
    final marker = payload.contains('\r\n\r\n') ? '\r\n\r\n' : '\n\n';
    final index = payload.indexOf(marker);
    if (index == -1) {
      return _HeaderBodySplit(headers: payload, body: '');
    }
    return _HeaderBodySplit(
      headers: payload.substring(0, index),
      body: payload.substring(index + marker.length),
    );
  }

  String? _extractHeader(String payload, String header) {
    final split = _splitHeadersAndBody(payload);
    final lines = split.headers.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final index = line.indexOf(':');
      if (index <= 0) {
        continue;
      }
      final name = line.substring(0, index).trim().toLowerCase();
      if (name != header.toLowerCase()) {
        continue;
      }
      return line.substring(index + 1).trim();
    }
    return null;
  }
}

class _HeaderBodySplit {
  const _HeaderBodySplit({
    required this.headers,
    required this.body,
  });

  final String headers;
  final String body;
}

class _HeaderBodySplitBytes {
  const _HeaderBodySplitBytes({
    required this.headers,
    required this.body,
  });

  final List<int> headers;
  final List<int> body;
}

class P2pInboundFrame {
  const P2pInboundFrame({
    required this.sessionId,
    required this.baseId,
    required this.offset,
    required this.totalSize,
    required this.messageSize,
    required this.flags,
    required this.slpText,
    this.ackSessionId = 0,
    this.ackUniqueId = 0,
  });

  final int sessionId;
  /// The sender's BaseID (identifier field at header offset 4).
  final int baseId;
  final int offset;
  final int totalSize;
  final int messageSize;
  final int flags;
  final String slpText;
  /// AckSessionID at offset 32 — identifies the session being ACK/NAK'd.
  final int ackSessionId;
  /// AckUniqueID at offset 36 — identifies the baseId being ACK/NAK'd.
  final int ackUniqueId;
}

/// Returned by [MsnSlpService.buildDisplayPictureInviteBinary] so the caller
/// can store the GUID identifiers needed to construct the SLP ACK later.
class P2pInviteResult {
  const P2pInviteResult({
    required this.bytes,
    required this.callId,
    required this.branchId,
    required this.sessionId,
    required this.baseId,
  });

  /// Raw P2P binary payload (48-byte header + SLP text + 4-byte footer).
  final List<int> bytes;

  /// The Call-ID GUID used in the INVITE, e.g. `{XXXXXXXX-XXXX-4XXX-YXXX-XXXXXXXXXXXX}`.
  final String callId;

  /// The branch GUID used in the Via header.
  final String branchId;

  /// The SessionID placed in the P2P transport header.
  final int sessionId;

  /// The BaseID (unique identifier) placed in the P2P transport header.
  final int baseId;
}
