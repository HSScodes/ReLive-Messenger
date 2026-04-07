import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Immutable snapshot of a single peer's P2P transfer state.
class P2pStatus {
  const P2pStatus({
    required this.message,
    this.bytesReceived = 0,
    this.totalSize = 0,
  });

  final String message;
  final int bytesReceived;
  final int totalSize;

  double get progress => totalSize > 0 ? bytesReceived / totalSize : 0.0;

  P2pStatus copyWith({String? message, int? bytesReceived, int? totalSize}) {
    return P2pStatus(
      message: message ?? this.message,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      totalSize: totalSize ?? this.totalSize,
    );
  }
}

/// Tracks the state of a single inbound P2P display-picture transfer.
class _P2pInboundSession {
  _P2pInboundSession({
    required this.sessionId,
    required this.peerEmail,
    required this.totalSize,
  }) : _buffer = Uint8List(totalSize.toInt() > 0 ? totalSize.toInt() : 0);

  final int sessionId;
  final String peerEmail;
  final int totalSize; // 64-bit value from header (fits in int for any real image)

  final Uint8List _buffer;
  int _bytesReceived = 0;

  bool get isComplete => _bytesReceived >= totalSize && totalSize > 0;

  /// Write [data] at [offset] inside the assembly buffer.
  void write(int offset, List<int> data) {
    if (offset < 0 || data.isEmpty) return;
    final end = offset + data.length;
    if (end > _buffer.length) return; // malformed — ignore
    _buffer.setRange(offset, end, data);
    _bytesReceived = _bytesReceived < end ? end : _bytesReceived;
  }

  Uint8List get assembledBytes => _buffer;
}

/// Manages all active inbound P2P display-picture sessions and gives back
/// the local file path when reassembly is complete.
///
/// The [onAvatarReady] callback is called on the Dart isolate that calls
/// [handleDataChunk] — wrap with a post-frame callback if needed for UI.
class P2pSessionManager {
  P2pSessionManager({required this.onAvatarReady});

  /// Called with (peerEmail, localFilePath, {sha1d}) when reassembly finishes.
  final void Function(String peerEmail, String filePath, {String? sha1d}) onAvatarReady;

  final Map<int, _P2pInboundSession> _sessions = {};

  /// Stores the GUIDs from the INVITE we sent, keyed by normalised peer email.
  /// The SLP-level ACK reply requires the same callId and branchId.
  final Map<String, _InviteParams> _inviteParams = {};

  /// SHA1D we requested for each peer, stored alongside invite params.
  final Map<String, String> _inviteSha1d = {};

  // ---- Status stream (for UI visualizer) ----------------------------------

  final Map<String, P2pStatus> _statusByEmail = {};
  final StreamController<Map<String, P2pStatus>> _statusController =
      StreamController.broadcast();

  /// Emits a new snapshot whenever any peer's status changes.
  Stream<Map<String, P2pStatus>> get statusStream => _statusController.stream;

  /// Latest snapshot; use `statusStream` for reactive updates.
  Map<String, P2pStatus> get currentStatus => Map.unmodifiable(_statusByEmail);

  /// Update the transfer status for [peerEmail] and push a new event.
  void updateStatus(
    String peerEmail,
    String message, {
    int bytesReceived = 0,
    int totalSize = 0,
  }) {
    final key = peerEmail.trim().toLowerCase();
    _statusByEmail[key] =
        P2pStatus(message: message, bytesReceived: bytesReceived, totalSize: totalSize);
    if (!_statusController.isClosed) {
      _statusController.add(Map.unmodifiable(_statusByEmail));
    }
  }

  // ---- Invite param storage -----------------------------------------------

  void storeInviteParams({
    required String peerEmail,
    required String callId,
    required String branchId,
    required int sessionId,
    required int baseId,
    String? sha1d,
  }) {
    final key = peerEmail.trim().toLowerCase();
    _inviteParams[key] = _InviteParams(
      callId: callId,
      branchId: branchId,
      sessionId: sessionId,
      baseId: baseId,
    );
    if (sha1d != null && sha1d.isNotEmpty) {
      _inviteSha1d[key] = sha1d;
    }
  }

  _InviteParams? getInviteParams(String peerEmail) {
    return _inviteParams[peerEmail.trim().toLowerCase()];
  }

  // ---- Session lifecycle --------------------------------------------------

  /// Open a new receiving session.  Called when we parse a 200 OK that
  /// carries a non-zero SessionID confirming the transfer will start.
  void openSession({
    required int sessionId,
    required String peerEmail,
    required int totalSize,
  }) {
    if (sessionId == 0) return;
    _sessions[sessionId] = _P2pInboundSession(
      sessionId: sessionId,
      peerEmail: peerEmail,
      totalSize: totalSize,
    );
    updateStatus(peerEmail, 'P2P: Session open — waiting for data...');
    print('[P2P] Opened session $sessionId for $peerEmail  total=$totalSize bytes');
  }

  /// Called for every inbound Flags=32 data chunk.
  /// [rawP2pBytes] is the raw binary after stripping the MIME headers — it
  /// starts with the 48-byte P2P transport header.
  Future<void> handleDataChunk({
    required int sessionId,
    required int offset,
    required int messageSize,
    required int totalSize,
    required String peerEmail,
    required List<int> rawP2pBytes,
  }) async {
    if (sessionId == 0 || messageSize == 0) return;

    // Lazily open session if 200 OK was missed, or update totalSize if the
    // session was previously opened with 0 (field missing from 200 OK body).
    final existing = _sessions[sessionId];
    if (existing == null || (existing.totalSize == 0 && totalSize > 0)) {
      _sessions[sessionId] = _P2pInboundSession(
        sessionId: sessionId,
        peerEmail: peerEmail,
        totalSize: totalSize,
      );
    }

    final session = _sessions[sessionId]!;

    // Data bytes start at index 48 (after P2P header), up to messageSize.
    final headerEnd = 48;
    if (rawP2pBytes.length < headerEnd) return;
    final available = rawP2pBytes.length - headerEnd;
    final takeBytes = messageSize < available ? messageSize : available;
    if (takeBytes <= 0) return;

    final dataSlice = rawP2pBytes.sublist(headerEnd, headerEnd + takeBytes);
    session.write(offset, dataSlice);

    updateStatus(
      session.peerEmail,
      'P2P: Downloading...',
      bytesReceived: session._bytesReceived,
      totalSize: session.totalSize,
    );
    print(
      '[P2P] Session $sessionId: received ${session._bytesReceived}/${session.totalSize} bytes',
    );

    if (session.isComplete) {
      _sessions.remove(sessionId);
      await _saveAndNotify(session);
    }
  }

  void closeSession(int sessionId) {
    _sessions.remove(sessionId);
  }

  // ---- File saving --------------------------------------------------------

  Future<void> _saveAndNotify(_P2pInboundSession session) async {
    try {
      final dir = await _avatarCacheDir();
      // Use session ID as unique filename so repeated fetches overwrite cleanly.
      final file = File('${dir.path}${Platform.pathSeparator}p2p_${session.peerEmail.replaceAll('@', '_at_')}_${session.sessionId}.png');
      await file.writeAsBytes(session.assembledBytes);
      print('[P2P] Saved avatar for ${session.peerEmail} → ${file.path}');
      updateStatus(
        session.peerEmail,
        'P2P: Complete!',
        bytesReceived: session.totalSize,
        totalSize: session.totalSize,
      );
      // Retrieve the SHA1D from the stored invite params so the AVOK event
      // carries the correct hash for the contacts provider to persist.
      final params = _inviteParams[session.peerEmail.trim().toLowerCase()];
      final sha1d = params != null ? _inviteSha1d[session.peerEmail.trim().toLowerCase()] : null;
      onAvatarReady(session.peerEmail, file.path, sha1d: sha1d);
    } catch (error) {
      print('[P2P] Failed to save avatar for ${session.peerEmail}: $error');
    }
  }

  Future<Directory> _avatarCacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}wlm_avatars');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

class _InviteParams {
  const _InviteParams({
    required this.callId,
    required this.branchId,
    required this.sessionId,
    required this.baseId,
  });

  final String callId;
  final String branchId;
  final int sessionId;
  final int baseId;
}
