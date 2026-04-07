import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// EUF-GUID for MSNP file transfer (P2P v1).
const String fileTransferEufGuid = '{5D3E02AB-6190-11D3-BBBB-00C04F795683}';

/// Represents a pending or active file transfer.
class FileTransferSession {
  FileTransferSession({
    required this.sessionId,
    required this.peerEmail,
    required this.fileName,
    required this.fileSize,
    required this.isOutgoing,
    required this.callId,
    required this.branchId,
    required this.baseId,
    this.localPath,
  });

  final int sessionId;
  final String peerEmail;
  final String fileName;
  final int fileSize;
  final bool isOutgoing;
  final String callId;
  final String branchId;
  final int baseId;
  String? localPath;

  // Reassembly buffer for incoming files
  Uint8List? _buffer;
  int _bytesTransferred = 0;
  DateTime? lastChunkTime;

  int get bytesTransferred => _bytesTransferred;
  double get progress => fileSize > 0 ? _bytesTransferred / fileSize : 0.0;
  bool get isComplete => _bytesTransferred == fileSize && fileSize > 0;

  void initBuffer() {
    _buffer ??= Uint8List(fileSize > 0 ? fileSize : 0);
  }

  void writeChunk(int offset, List<int> data) {
    _buffer ??= Uint8List(fileSize > 0 ? fileSize : 0);
    if (offset < 0 || data.isEmpty) return;
    final end = offset + data.length;
    if (end > _buffer!.length) return;
    _buffer!.setRange(offset, end, data);
    if (_bytesTransferred < end) _bytesTransferred = end;
  }

  Uint8List get assembledBytes => _buffer ?? Uint8List(0);
}

/// Manages MSNSLP file transfer negotiation and data chunking.
class FileTransferService {
  final Random _random = Random();
  final Map<int, FileTransferSession> _sessions = {};
  final Map<String, FileTransferSession> _sessionsByCallId = {};
  final Map<int, Timer> _stallTimers = {};

  /// Stream of stalled/failed transfers
  final StreamController<FileTransferSession> _failedController =
      StreamController.broadcast();
  Stream<FileTransferSession> get failedStream => _failedController.stream;

  /// Stream of transfer progress updates: (sessionId, bytesTransferred, totalSize)
  final StreamController<FileTransferSession> _progressController =
      StreamController.broadcast();
  Stream<FileTransferSession> get progressStream => _progressController.stream;

  /// Stream of completed transfers
  final StreamController<FileTransferSession> _completedController =
      StreamController.broadcast();
  Stream<FileTransferSession> get completedStream =>
      _completedController.stream;

  /// Stream of incoming transfer offers that need user acceptance
  final StreamController<FileTransferSession> _offerController =
      StreamController.broadcast();
  Stream<FileTransferSession> get offerStream => _offerController.stream;

  FileTransferSession? getSession(int sessionId) => _sessions[sessionId];
  FileTransferSession? getSessionByCallId(String callId) =>
      _sessionsByCallId[callId];

  /// Remove a session after it has been completed or cleaned up externally.
  void removeSession(int sessionId) {
    final s = _sessions.remove(sessionId);
    if (s != null) _sessionsByCallId.remove(s.callId);
    _stallTimers.remove(sessionId)?.cancel();
  }

  // ── Outbound: build INVITE for sending a file ──────────────────────────

  /// Builds the MSNSLP INVITE + P2P binary frame for offering a file.
  /// Returns the raw bytes to send over switchboard + the session metadata.
  FileTransferInviteResult buildFileTransferInvite({
    required String contactEmail,
    required String myEmail,
    required String fileName,
    required int fileSize,
  }) {
    final branchId = '{${_newGuid()}}';
    final callId = '{${_newGuid()}}';
    final sessionId = _random.nextInt(0x7FFFFFFE) + 1;
    final baseId = _random.nextInt(0x7fffffff);

    // Build the Context blob (MSNP file transfer format):
    // 574 bytes total, little-endian:
    //   [0..3]   = total size of context (574)
    //   [4..7]   = type (0x01 = file preview, 0x00 = no preview)
    //   [8..15]  = file size (uint64 LE)
    //   [16..19] = flags (0x01)
    //   [20..539] = filename (Unicode LE, null-terminated, 520 bytes max)
    //   [540..573] = padding/reserved
    final contextBytes = Uint8List(574);
    final contextData = ByteData.sublistView(contextBytes);
    contextData.setUint32(0, 574, Endian.little);
    contextData.setUint32(4, 0, Endian.little); // no preview
    contextData.setUint64(8, fileSize, Endian.little);
    contextData.setUint32(16, 0x01, Endian.little);

    // Write filename as UTF-16LE (max 260 chars = 520 bytes)
    final nameChars = fileName.codeUnits;
    final maxChars = nameChars.length > 260 ? 260 : nameChars.length;
    for (var i = 0; i < maxChars; i++) {
      contextData.setUint16(20 + i * 2, nameChars[i], Endian.little);
    }

    final context = base64.encode(contextBytes);

    final bodyText =
        'EUF-GUID: $fileTransferEufGuid\r\n'
        'SessionID: $sessionId\r\n'
        'AppID: 2\r\n'
        'Context: $context\r\n\r\n';
    final bodyLength = utf8.encode(bodyText).length;

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

    final p2pBytes = _buildP2pPayload(0, baseId, 0, slpText);

    final session = FileTransferSession(
      sessionId: sessionId,
      peerEmail: contactEmail,
      fileName: fileName,
      fileSize: fileSize,
      isOutgoing: true,
      callId: callId,
      branchId: branchId,
      baseId: baseId,
    );
    _sessions[sessionId] = session;
    _sessionsByCallId[callId] = session;

    return FileTransferInviteResult(bytes: p2pBytes, session: session);
  }

  // ── Inbound: parse incoming INVITE ─────────────────────────────────────

  /// Parses an incoming MSNSLP INVITE for a file transfer.
  /// Returns null if the SLP text is not a file transfer invite.
  FileTransferSession? parseIncomingInvite({
    required String slpText,
    required String from,
    required int baseId,
  }) {
    if (!slpText.contains(fileTransferEufGuid)) return null;
    if (!slpText.contains('INVITE ')) return null;

    final sessionId = _extractInt(slpText, 'SessionID');
    if (sessionId == null || sessionId == 0) return null;

    final callId = _extractHeader(slpText, 'Call-ID') ?? '';
    final branchId = _extractVia(slpText) ?? '';
    final contextB64 = _extractHeader(slpText, 'Context') ?? '';

    String fileName = 'unknown';
    int fileSize = 0;

    print(
      '[FT] parseIncomingInvite: sessionId=$sessionId callId=$callId '
      'contextB64.length=${contextB64.length} '
      'contextB64=${contextB64.length > 80 ? "${contextB64.substring(0, 80)}..." : contextB64}',
    );

    if (contextB64.isNotEmpty) {
      try {
        // Strip any non-base64 characters (whitespace, stray bytes, etc.)
        var b64 = contextB64.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
        // Remove any existing padding before re-padding
        b64 = b64.replaceAll('=', '');
        // 4n+1 is never valid base64; trim the trailing garbage char
        if (b64.length % 4 == 1 && b64.isNotEmpty) {
          print(
            '[FT] Context base64 length ${b64.length} is 4n+1 — trimming last char',
          );
          b64 = b64.substring(0, b64.length - 1);
        }
        // Re-add proper padding
        while (b64.length % 4 != 0) {
          b64 += '=';
        }
        final contextBytes = base64.decode(b64);
        print('[FT] Context decoded: ${contextBytes.length} bytes');
        if (contextBytes.length >= 20) {
          final data = ByteData.sublistView(Uint8List.fromList(contextBytes));
          fileSize = data.getUint64(8, Endian.little);

          // Read filename as UTF-16LE starting at offset 20
          final nameBytes = <int>[];
          for (var i = 20; i + 1 < contextBytes.length && i < 540; i += 2) {
            final char = data.getUint16(i, Endian.little);
            if (char == 0) break;
            nameBytes.add(char);
          }
          if (nameBytes.isNotEmpty) {
            fileName = String.fromCharCodes(nameBytes);
          }
          print('[FT] Parsed: fileName=$fileName fileSize=$fileSize');
        }
      } catch (e) {
        print('[FT] Context parse error: $e');
      }
    } else {
      print('[FT] WARNING: Context header empty or not found in SLP body');
    }

    final session = FileTransferSession(
      sessionId: sessionId,
      peerEmail: from,
      fileName: fileName,
      fileSize: fileSize,
      isOutgoing: false,
      callId: callId,
      branchId: branchId,
      baseId: baseId,
    );
    _sessions[sessionId] = session;
    _sessionsByCallId[callId] = session;
    _offerController.add(session);
    return session;
  }

  // ── Accept / Decline ───────────────────────────────────────────────────

  /// Builds a 200 OK response accepting the file transfer.
  List<int> buildAcceptResponse({
    required int sessionId,
    required String myEmail,
    required String peerEmail,
  }) {
    final session = _sessions[sessionId];
    if (session == null) return const [];

    session.initBuffer();

    final bodyText = 'SessionID: $sessionId\r\n\r\n';
    final bodyLength = utf8.encode(bodyText).length;

    final slpText = [
      'MSNSLP/1.0 200 OK',
      'To: <msnmsgr:$peerEmail>',
      'From: <msnmsgr:$myEmail>',
      'Via: MSNSLP/1.0/TLP ;branch=${session.branchId}',
      'CSeq: 1',
      'Call-ID: ${session.callId}',
      'Max-Forwards: 0',
      'Content-Type: application/x-msnmsgr-sessionreqbody',
      'Content-Length: $bodyLength',
      '',
      bodyText,
    ].join('\r\n');

    final baseId = _random.nextInt(0x7fffffff);
    return _buildP2pPayload(0, baseId, 0, slpText);
  }

  /// Builds a 603 Decline response.
  List<int> buildDeclineResponse({
    required int sessionId,
    required String myEmail,
    required String peerEmail,
  }) {
    final session = _sessions[sessionId];
    if (session == null) return const [];

    final slpText = [
      'MSNSLP/1.0 603 Decline',
      'To: <msnmsgr:$peerEmail>',
      'From: <msnmsgr:$myEmail>',
      'Via: MSNSLP/1.0/TLP ;branch=${session.branchId}',
      'CSeq: 1',
      'Call-ID: ${session.callId}',
      'Max-Forwards: 0',
      'Content-Type: application/x-msnmsgr-sessionreqbody',
      'Content-Length: 0',
      '',
      '',
    ].join('\r\n');

    _sessions.remove(sessionId);
    _sessionsByCallId.remove(session.callId);

    final baseId = _random.nextInt(0x7fffffff);
    return _buildP2pPayload(0, baseId, 0, slpText);
  }

  // ── Outbound data chunking ─────────────────────────────────────────────

  /// Generates P2P data frames for sending the file contents.
  /// Each frame has a 48-byte header + up to [chunkSize] bytes of data + 4-byte footer.
  /// The SB MSG limit is ~1202 bytes, so chunkSize should be ≤ 1150.
  Iterable<List<int>> chunkFileForSending({
    required int sessionId,
    required Uint8List fileBytes,
    int chunkSize = 1150,
    int? baseId,
  }) sync* {
    final session = _sessions[sessionId];
    if (session == null) return;

    final totalSize = fileBytes.length;
    var offset = 0;
    final effectiveBaseId = baseId ?? _random.nextInt(0x7fffffff);

    while (offset < totalSize) {
      final remaining = totalSize - offset;
      final thisChunk = remaining > chunkSize ? chunkSize : remaining;
      final chunkBytes = fileBytes.sublist(offset, offset + thisChunk);

      final header = ByteData(48);
      header.setUint32(0, sessionId, Endian.little);
      header.setUint32(4, effectiveBaseId, Endian.little);
      header.setUint64(8, offset, Endian.little);
      header.setUint64(16, totalSize, Endian.little);
      header.setUint32(24, thisChunk, Endian.little);
      header.setUint32(28, 0x20, Endian.little); // Flags = 0x20 (data)
      // Rest of header is zero (ack fields)

      // 4-byte footer: AppID for file transfer
      final footer = ByteData(4);
      footer.setUint32(0, 2, Endian.big); // AppID 2 = file transfer

      yield <int>[
        ...header.buffer.asUint8List(),
        ...chunkBytes,
        ...footer.buffer.asUint8List(),
      ];

      offset += thisChunk;
      session._bytesTransferred = offset;
      _progressController.add(session);
    }
  }

  // ── Inbound data handling ──────────────────────────────────────────────

  /// Feed an incoming P2P data chunk into the correct session.
  Future<void> handleDataChunk({
    required int sessionId,
    required int offset,
    required int messageSize,
    required int totalSize,
    required List<int> rawP2pBytes,
  }) async {
    final session = _sessions[sessionId];
    if (session == null || session.isOutgoing) return;

    session.initBuffer();

    const headerEnd = 48;
    if (rawP2pBytes.length < headerEnd) return;
    final available = rawP2pBytes.length - headerEnd;
    final takeBytes = messageSize < available ? messageSize : available;
    if (takeBytes <= 0) return;

    final dataSlice = rawP2pBytes.sublist(headerEnd, headerEnd + takeBytes);
    session.writeChunk(offset, dataSlice);
    session.lastChunkTime = DateTime.now();
    _progressController.add(session);

    print(
      '[FT] handleDataChunk: session=$sessionId offset=$offset '
      'takeBytes=$takeBytes transferred=${session.bytesTransferred}/${session.fileSize} '
      'isComplete=${session.isComplete}',
    );

    if (session.isComplete) {
      print('[FT] Transfer complete — saving file: ${session.fileName}');
      _stallTimers.remove(sessionId)?.cancel();
      // Remove from maps immediately to prevent duplicate save attempts
      // from retransmitted chunks while the async save is in-flight.
      _sessions.remove(sessionId);
      _sessionsByCallId.remove(session.callId);
      await _saveCompletedFile(session);
    } else {
      _resetStallTimer(sessionId);
    }
  }

  Future<void> _saveCompletedFile(FileTransferSession session) async {
    try {
      final dir = await _downloadDir();
      // Sanitize filename
      final safeName = session.fileName
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final file = File('${dir.path}${Platform.pathSeparator}$safeName');
      print(
        '[FT] Saving file: ${file.path} (${session.assembledBytes.length} bytes)',
      );
      await file.writeAsBytes(session.assembledBytes, flush: true);
      session.localPath = file.path;
      print('[FT] File saved successfully: ${file.path}');
      _completedController.add(session);
    } catch (e) {
      print('[FT] ERROR saving file: $e\n${StackTrace.current}');
      _failedController.add(session);
    }
  }

  Future<Directory> _downloadDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${docs.path}${Platform.pathSeparator}wlm_received_files',
    );
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  // ── BYE ────────────────────────────────────────────────────────────────

  /// Builds a BYE SLP message for ending a session.
  List<int> buildBye({
    required int sessionId,
    required String myEmail,
    required String peerEmail,
  }) {
    final session = _sessions[sessionId];
    if (session == null) return const [];

    final slpText = [
      'BYE MSNMSGR:$peerEmail MSNSLP/1.0',
      'To: <msnmsgr:$peerEmail>',
      'From: <msnmsgr:$myEmail>',
      'Via: MSNSLP/1.0/TLP ;branch=${session.branchId}',
      'CSeq: 0',
      'Call-ID: ${session.callId}',
      'Max-Forwards: 0',
      'Content-Type: application/x-msnmsgr-sessionclosebody',
      'Content-Length: 0',
      '',
      '',
    ].join('\r\n');

    _sessions.remove(sessionId);
    _sessionsByCallId.remove(session.callId);

    final baseId = _random.nextInt(0x7fffffff);
    return _buildP2pPayload(0, baseId, 0, slpText);
  }

  void dispose() {
    for (final t in _stallTimers.values) {
      t.cancel();
    }
    _stallTimers.clear();
    _progressController.close();
    _completedController.close();
    _offerController.close();
    _failedController.close();
  }

  /// Immediately fail all active (non-complete) incoming file transfer
  /// sessions with [peerEmail].  Called when the switchboard to this peer
  /// closes unexpectedly.
  void failActiveSessionsForPeer(String peerEmail) {
    final normalised = peerEmail.toLowerCase().trim();
    final toFail = _sessions.values
        .where(
          (s) =>
              !s.isOutgoing &&
              !s.isComplete &&
              s.peerEmail.toLowerCase().trim() == normalised,
        )
        .toList();
    for (final s in toFail) {
      _stallTimers.remove(s.sessionId)?.cancel();
      _sessions.remove(s.sessionId);
      _sessionsByCallId.remove(s.callId);
      _failedController.add(s);
      print('[FT] Session ${s.sessionId} failed — SB closed for $normalised');
    }
  }

  /// Resets the 30-second stall watchdog for [sessionId].
  void _resetStallTimer(int sessionId) {
    _stallTimers[sessionId]?.cancel();
    _stallTimers[sessionId] = Timer(const Duration(seconds: 30), () {
      final session = _sessions[sessionId];
      if (session != null && !session.isComplete) {
        _sessions.remove(sessionId);
        _sessionsByCallId.remove(session.callId);
        _stallTimers.remove(sessionId);
        _failedController.add(session);
      }
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  List<int> _buildP2pPayload(
    int sessionId,
    int baseId,
    int flags,
    String slpText, {
    int footer = 0,
  }) {
    // Null-terminate the SLP text on the wire.  TotalDataSize / MessageSize
    // INCLUDE the null terminator (matching WLM 2009 / MSNPSharp).
    final rawSlpBytes = utf8.encode(slpText);
    final slpBytes = [...rawSlpBytes, 0];
    final bodyLength = slpBytes.length; // WITH null terminator

    final header = ByteData(48);
    header.setUint32(0, sessionId, Endian.little);
    header.setUint32(4, baseId, Endian.little);
    header.setUint64(8, 0, Endian.little);
    header.setUint64(16, bodyLength, Endian.little);
    header.setUint32(24, bodyLength, Endian.little);
    header.setUint32(28, flags, Endian.little);

    final footerBytes = ByteData(4);
    footerBytes.setUint32(0, footer, Endian.big);

    return <int>[
      ...header.buffer.asUint8List(),
      ...slpBytes,
      ...footerBytes.buffer.asUint8List(),
    ];
  }

  String _newGuid() {
    final r = _random;
    String hex(int n) {
      // nextInt max is 2^32-1 but practical safe limit is 2^31-1.
      // Cap bit shift at 30 so 1<<30 = 1073741824 which is safely < 2^31.
      final maxBits = (n * 4).clamp(1, 30);
      return r.nextInt(1 << maxBits).toRadixString(16).padLeft(n, '0');
    }

    return '${hex(4)}${hex(4)}-${hex(4)}-4${hex(3)}-${(8 + r.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(4)}${hex(4)}${hex(4)}';
  }

  int? _extractInt(String text, String name) {
    final re = RegExp('$name:\\s*(\\d+)', caseSensitive: false);
    final m = re.firstMatch(text);
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  String? _extractHeader(String text, String name) {
    final re = RegExp('$name:\\s*(.+)', caseSensitive: false);
    final m = re.firstMatch(text);
    return m?.group(1)?.trim();
  }

  String? _extractVia(String text) {
    final re = RegExp(r'Via:.*?;branch=(\{[^}]+\})', caseSensitive: false);
    final m = re.firstMatch(text);
    return m?.group(1);
  }
}

class FileTransferInviteResult {
  const FileTransferInviteResult({required this.bytes, required this.session});

  final List<int> bytes;
  final FileTransferSession session;
}
