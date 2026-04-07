// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/server_config.dart';
import '../services/abch_service.dart';
import '../services/file_transfer_service.dart';
import '../services/msn_object_service.dart';
import '../services/msn_slp_service.dart';
import '../services/p2p_session_manager.dart';
import '../utils/presence_status.dart';
import 'msnp_commands.dart';
import 'msnp_parser.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  authenticating,
  connected,
  error,
}

class MsnpClient {
  static bool _knownServerSynUnsupported = false;
  static const bool _enableAbch = true;
  static const String _wlm14ProductKey = r'C1BX{V4W}Q3*10SM';
  static const String endpointGuid = '{F91E6A6A-AF26-4A6A-8450-34D45A46DBCE}';

  static const List<_ChallengeProfile> _challengeProfiles = <_ChallengeProfile>[
    _ChallengeProfile(
      qryTarget: MsnpCommands.msnQryTargetWlm14,
      productKey: _wlm14ProductKey,
      mode: _ChallengeMode.md5,
    ),
  ];

  Socket? _socket;
  Socket? _sbSocket;
  int _trId = 0;
  int _sbTrId = 0;
  int? _lastSynTrId;
  int? _lastQryTrId;
  bool _serverSupportsSyn = false;
  bool _synRejected = false;
  int _synAttemptStage = 0;
  bool _synRetriedAfterChallenge = false;
  bool _sentLegacySyncBootstrap = false;
  bool _sentPostAuthBootstrap = false;
  Timer? _challengeAckTimer;
  int? _activeChallengeTrId;
  bool _challengeAcked = false;
  int _challengeRetryCount = 0;
  int _challengeProfileIndex = 0;
  String? _lastChallenge;
  Timer? _keepAliveTimer;
  int _keepAliveSeconds = 45;
  final List<int> _rxBuffer = <int>[];
  final List<int> _sbRxBuffer = <int>[];
  final Map<String, _KnownContact> _knownContacts = <String, _KnownContact>{};
  final AbchService _abchService = AbchService();
  final MsnSlpService _slpService = MsnSlpService();
  final MsnObjectService _msnObjectService = MsnObjectService();
  late final P2pSessionManager _p2pSessionManager = P2pSessionManager(
    onAvatarReady: _onP2pAvatarReady,
  );

  /// Exposes the P2P session manager so providers can observe transfer status.
  P2pSessionManager get p2pSessionManager => _p2pSessionManager;

  final FileTransferService _fileTransferService = FileTransferService();

  /// Exposes the file transfer service for providers / UI.
  FileTransferService get fileTransferService => _fileTransferService;
  final Set<String> _avatarInviteSent = <String>{};
  final Set<String> _avatarInvitePending = <String>{};
  final Set<String> _avatarSilentRequested = <String>{};
  final Set<String> _avatarBackgroundFailed = <String>{};
  final Map<String, int> _avatarSbRetryCount = <String, int>{};
  final Map<int, String> _pendingXfrRequests = <int, String>{};

  /// Deferred RNG invitations that arrived while the P2P avatar pipeline was
  /// busy. Each entry holds the raw RNG line. Processed in FIFO order when the
  /// pipeline goes idle.
  final List<String> _deferredRngLines = <String>[];

  _PendingFrame? _pendingFrame;
  _PendingFrame? _sbPendingFrame;
  final List<_PendingOutboundMessage> _sbOutboundQueue =
      <_PendingOutboundMessage>[];
  String? _sbSessionId;
  String? _sbAuthToken;
  String? _sbHost;
  int? _sbPort;
  String? _sbContactEmail;
  bool _sbIsInviteMode = false;
  bool _sbIsSilentAvatarSession = false;
  bool _sbReady = false;
  bool _sbConnecting = false;
  bool _sbAwaitingXfr = false;
  Timer? _sbJoinTimeoutTimer;
  String? _sbJoinTimeoutContact;
  String? _sbPendingRecipient;

  /// Email of the contact whose P2P INVITE we have sent and are waiting on
  /// (transport ACK + 200 OK + data). While this is non-null, no other SB
  /// connection may be started so that the in-progress session can complete.
  String? _sbP2pInFlightEmail;
  Timer? _sbP2pResponseTimeout;

  /// Per-contact avatar stall timers (15s timeout per avatar transfer).
  final Map<String, Timer> _avatarStallTimers = <String, Timer>{};

  /// Session IDs for which we already started serving our avatar.
  /// Prevents duplicate processing when the same INVITE is received
  /// multiple times on the same SB connection.
  final Set<int> _handledAvatarSessionIds = <int>{};

  /// Completers to await peer's data-complete ACK (Flags=0x02) per session.
  final Map<int, Completer<void>> _ftDataAckCompleters =
      <int, Completer<void>>{};
  Timer? _sbXfrTimeout;
  Timer? _sbQueueWatchdog;
  String _email = '';
  String _selfDisplayName = '';
  String _ticket = '';
  String? _mspAuth;
  String? _mspProf;
  String? _sid;
  String? _selfAvatarMsnObject;
  String? _selfAvatarPath;
  String _selfPsm = '';
  String _selfCurrentMedia = '';
  String _selfScene = '';
  String _selfColorScheme = '-1';
  PresenceStatus _selfPresence = PresenceStatus.online;
  String _connectedHost = ServerConfig.host;
  bool _abchFetchStarted = false;
  bool _abchRetryWithProfileTokensDone = false;
  bool _abchFetchReturnedEmpty = false;

  final StreamController<MsnpEvent> _eventController =
      StreamController<MsnpEvent>.broadcast();
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();

  Stream<MsnpEvent> get events => _eventController.stream;
  Stream<ConnectionStatus> get status => _statusController.stream;

  List<MsnpContactSnapshot> get contactSnapshot {
    return _knownContacts.values
        .map(
          (c) => MsnpContactSnapshot(
            email: c.email,
            displayName: c.displayName,
            status: c.status,
            personalMessage: c.personalMessage,
            nowPlaying: c.nowPlaying,
            avatarMsnObject: c.avatarMsnObject,
            avatarCreator: c.avatarCreator,
            avatarSha1d: c.avatarSha1d,
            ddpMsnObject: c.ddpMsnObject,
            ddpSha1d: c.ddpSha1d,
            scene: c.scene,
            colorScheme: c.colorScheme,
          ),
        )
        .toList(growable: false);
  }

  bool get isConnected => _socket != null;
  String get sessionTicket => _ticket;
  String get sessionHost => _connectedHost;
  String get selfEmail => _email;
  String get selfDisplayName {
    if (_selfDisplayName.isNotEmpty) return _selfDisplayName;
    return _email;
  }

  String? get selfAvatarMsnObject => _selfAvatarMsnObject;
  String get selfScene => _selfScene;
  String get selfColorScheme => _selfColorScheme;
  String get selfPsm => _selfPsm;
  PresenceStatus get selfPresence => _selfPresence;
  String get avatarAuthToken {
    final msp = (_mspAuth ?? '').trim();
    if (msp.isNotEmpty) {
      return msp;
    }
    return _ticket;
  }

  /// Sends a UUX payload to the server, broadcasting our personal message,
  /// scene, colour scheme, etc. to all online contacts.
  void _sendUux() {
    if (_socket == null) return;
    final machineGuid = endpointGuid;
    // Include the avatar MSNObject in <DDP> so contacts can fetch our avatar.
    final ddpContent =
        _selfAvatarMsnObject != null && _selfAvatarMsnObject!.isNotEmpty
        ? _xmlEscape(_selfAvatarMsnObject!)
        : '';
    final payload =
        '<Data>'
        '<PSM>${_xmlEscape(_selfPsm)}</PSM>'
        '<CurrentMedia>${_xmlEscape(_selfCurrentMedia)}</CurrentMedia>'
        '<MachineGuid>$machineGuid</MachineGuid>'
        '<DDP>$ddpContent</DDP>'
        '<SignatureSound></SignatureSound>'
        '<Scene>${_xmlEscape(_selfScene)}</Scene>'
        '<ColorScheme>${_xmlEscape(_selfColorScheme)}</ColorScheme>'
        '</Data>';
    _send(MsnpCommands.uux(_nextTrId(), payload));
    _log(
      'UUX sent: psm=${_selfPsm.isEmpty ? "(empty)" : _selfPsm}, '
      'scene=${_selfScene.isEmpty ? "(default)" : "(custom)"}, '
      'colorScheme=$_selfColorScheme, '
      'ddp=${ddpContent.isEmpty ? "(none)" : "(set)"}',
    );
  }

  /// Updates the personal status message and broadcasts via UUX.
  void setPersonalMessage(String psm) {
    _selfPsm = psm;
    _sendUux();
    // Persist so it survives app restarts
    _savePsm(psm);
  }

  /// Persist PSM for the current account.
  Future<void> _savePsm(String psm) async {
    if (_email.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wlm_psm_${_email.toLowerCase()}', psm);
  }

  /// Load previously persisted PSM for [email].
  Future<String> _loadPsm(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('wlm_psm_${email.toLowerCase()}') ?? '';
  }

  Future<void> _saveSelfDisplayName(String name) async {
    if (_email.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wlm_display_name_${_email.toLowerCase()}', name);
  }

  Future<String> _loadSelfDisplayName(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('wlm_display_name_${email.toLowerCase()}') ?? '';
  }

  Future<void> _saveSelfScene(String scene) async {
    if (_email.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wlm_scene_${_email.toLowerCase()}', scene);
  }

  Future<String> _loadSelfScene(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('wlm_scene_${email.toLowerCase()}') ?? '';
  }

  Future<void> _saveSelfColorScheme(String colorScheme) async {
    if (_email.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'wlm_color_scheme_${_email.toLowerCase()}',
      colorScheme,
    );
  }

  Future<String> _loadSelfColorScheme(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('wlm_color_scheme_${email.toLowerCase()}') ?? '-1';
  }

  /// Pre-loads the persisted avatar file and generates MSNObject so it's
  /// available for the very first CHG/UUX sent during bootstrap.
  Future<void> _preloadSelfAvatar(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'wlm_self_avatar_path_${email.trim().toLowerCase()}';
    final path = prefs.getString(key);
    _log('_preloadSelfAvatar: key=$key path=${path ?? 'NULL'}');
    if (path == null || path.isEmpty) {
      _log('_preloadSelfAvatar: no persisted avatar path, skipping');
      return;
    }
    final file = File(path);
    if (!file.existsSync()) {
      _log('_preloadSelfAvatar: file does not exist at $path');
      return;
    }
    _log('_preloadSelfAvatar: file exists, size=${file.lengthSync()} bytes');
    // Skip oversized avatars — the profile provider will resize and re-broadcast.
    if (file.lengthSync() > 100 * 1024) {
      _log(
        '_preloadSelfAvatar: file too large (>${100 * 1024}B), deferring to provider resize',
      );
      return;
    }
    final msnObj = await _msnObjectService.generateMsnObjectXml(
      creatorEmail: email,
      avatarFilePath: path,
      friendlyName: selfDisplayName,
    );
    if (msnObj == null) {
      _log('_preloadSelfAvatar: generateMsnObjectXml returned null!');
      return;
    }
    _selfAvatarMsnObject = msnObj;
    _selfAvatarPath = path;
    _log('Pre-loaded avatar MSNObject from $path (${msnObj.length} chars)');
    _log('MSNObject XML: $msnObj');
  }

  /// Sends an MSNP PNG keepalive to the server. Called from the foreground
  /// service callback to keep the session alive while the app is backgrounded.
  void sendPing() {
    if (_socket == null) return;
    _send(MsnpCommands.png());
  }

  /// Updates the scene (base64 image data or empty for default) and broadcasts.
  void setScene(String scene) {
    _selfScene = scene;
    unawaited(_saveSelfScene(scene));
    _sendUux();
  }

  /// Updates the colour scheme (packed signed int, e.g. "-1" for default) and broadcasts.
  void setColorScheme(String colorScheme) {
    _selfColorScheme = colorScheme;
    unawaited(_saveSelfColorScheme(colorScheme));
    _sendUux();
  }

  /// Updates the user's display (friendly) name on the server via PRP MFN.
  void setDisplayName(String name) {
    _selfDisplayName = name;
    unawaited(_saveSelfDisplayName(name));
    if (_socket == null) return;
    final encoded = Uri.encodeComponent(name);
    _send(MsnpCommands.prpMfn(_nextTrId(), encoded));
    _log('PRP MFN sent: $name');
  }

  /// Updates multiple self-status fields at once and sends a single UUX.
  void updateExtendedStatus({
    String? psm,
    String? currentMedia,
    String? scene,
    String? colorScheme,
  }) {
    if (psm != null) _selfPsm = psm;
    if (currentMedia != null) _selfCurrentMedia = currentMedia;
    if (scene != null) _selfScene = scene;
    if (colorScheme != null) _selfColorScheme = colorScheme;
    if (scene != null) {
      unawaited(_saveSelfScene(scene));
    }
    if (colorScheme != null) {
      unawaited(_saveSelfColorScheme(colorScheme));
    }
    _sendUux();
  }

  static String _xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  Future<void> connect({
    required String email,
    required String password,
    required String passportTicket,
    String host = ServerConfig.host,
    int port = ServerConfig.port,
  }) async {
    _email = email.trim().toLowerCase();
    _connectedHost = host;
    _keepAliveSeconds = 45;

    // Restore persisted PSM so it's broadcast in the first UUX after auth.
    _selfPsm = await _loadPsm(email);
    _selfDisplayName = await _loadSelfDisplayName(email);
    _selfScene = await _loadSelfScene(email);
    _selfColorScheme = await _loadSelfColorScheme(email);

    // Pre-load persisted avatar so the first CHG/UUX include the MSNObject.
    await _preloadSelfAvatar(email);

    _synAttemptStage = 0;
    _synRetriedAfterChallenge = false;
    _sentLegacySyncBootstrap = false;
    _sentPostAuthBootstrap = false;
    _challengeAcked = false;
    _activeChallengeTrId = null;
    _challengeRetryCount = 0;
    _challengeAckTimer?.cancel();
    _challengeAckTimer = null;
    _serverSupportsSyn = false;
    _lastChallenge = null;
    _lastQryTrId = null;
    _abchFetchStarted = false;
    _abchRetryWithProfileTokensDone = false;
    _abchFetchReturnedEmpty = false;
    _mspAuth = null;
    _mspProf = null;
    _sid = null;
    // _selfAvatarMsnObject is set by _preloadSelfAvatar() above — don't reset it.
    _knownContacts.clear();
    _avatarInviteSent.clear();
    _avatarInvitePending.clear();
    _avatarSilentRequested.clear();
    _avatarBackgroundFailed.clear();
    _pendingXfrRequests.clear();
    _sbP2pInFlightEmail = null;
    _sbP2pResponseTimeout?.cancel();
    _sbP2pResponseTimeout = null;
    _log('Connecting to $host:$port for $email');

    _statusController.add(ConnectionStatus.connecting);

    try {
      _statusController.add(ConnectionStatus.authenticating);
      _ticket = await _resolveTicket(
        host: host,
        email: email,
        password: password,
        fallbackTicket: passportTicket,
      );

      _log('Opening MSNP socket to $host:$port');
      _socket = await Socket.connect(
        host,
        port,
        timeout: ServerConfig.connectTimeout,
      );
      _socket!.listen(
        _onData,
        onDone: _onDone,
        onError: _onError,
        cancelOnError: false,
      );

      _log('Socket connected to $host:$port');
      _send(MsnpCommands.ver(_nextTrId()));
      _startSbQueueWatchdog();
    } on SocketException {
      _log('SocketException while connecting/authenticating.');
      _statusController.add(ConnectionStatus.error);
      rethrow;
    } on TimeoutException {
      _log('Timeout while connecting/authenticating.');
      _statusController.add(ConnectionStatus.error);
      rethrow;
    }
  }

  Future<void> setPresence(PresenceStatus status) async {
    if (_socket == null) {
      return;
    }
    _selfPresence = status;
    _send(
      MsnpCommands.chg(
        _nextTrId(),
        presenceToMsnp(status),
        capabilities: MsnpCommands.wlm2009Capabilities,
        msnObject: _encodedSelfMsnObject,
      ),
    );
  }

  /// URL-encoded MSNObject for inclusion in CHG commands.
  String? get _encodedSelfMsnObject {
    if (_selfAvatarMsnObject == null || _selfAvatarMsnObject!.isEmpty)
      return null;
    return Uri.encodeComponent(_selfAvatarMsnObject!);
  }

  /// (Re)generates the local MSNObject from [avatarPath] and broadcasts it.
  /// Called after the user picks a new avatar or on connect with a persisted one.
  Future<void> updateSelfAvatarMsnObject(String? avatarPath) async {
    if (avatarPath == null || avatarPath.isEmpty) {
      _selfAvatarMsnObject = null;
      return;
    }
    final msnObj = await _msnObjectService.generateMsnObjectXml(
      creatorEmail: _email,
      avatarFilePath: avatarPath,
      friendlyName: selfDisplayName,
    );
    if (msnObj == null) return;
    _selfAvatarMsnObject = msnObj;
    _selfAvatarPath = avatarPath;
    _handledAvatarSessionIds.clear();
    _log('Self avatar MSNObject updated: ${msnObj.length} chars');
    // Rebroadcast presence and UUX with the new MSNObject.
    if (_socket != null) {
      _send(
        MsnpCommands.chg(
          _nextTrId(),
          presenceToMsnp(_selfPresence),
          capabilities: MsnpCommands.wlm2009Capabilities,
          msnObject: _encodedSelfMsnObject,
        ),
      );
      _sendUux();
    }
  }

  Future<void> sendInstantMessage({
    required String to,
    required String body,
  }) async {
    final cleanBody = body.trim();
    if (cleanBody.isEmpty) {
      return;
    }

    final payload = StringBuffer()
      ..write('MIME-Version: 1.0\r\n')
      ..write('Content-Type: text/plain; charset=UTF-8\r\n')
      ..write('X-MMS-IM-Format: FN=Segoe%20UI; EF=; CO=0; CS=1; PF=0\r\n')
      ..write('\r\n')
      ..write(cleanBody);
    _sendToSwitchboard(
      to: to,
      payloadBytes: utf8.encode(payload.toString()),
      debugLabel: payload.toString(),
      fallbackToNotificationServer: true,
    );
  }

  void requestAvatarFetchForContact(String email, {bool force = false}) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    if (!force && !_avatarBackgroundFailed.contains(normalized)) {
      return;
    }
    if (force) {
      _avatarBackgroundFailed.remove(normalized);
      // Only clear the dedup/XFR-pending locks when there is NO active INVITE
      // in progress.  Clearing them while a MSNSLP INVITE has already been sent
      // but the 200 OK has not yet arrived causes a duplicate INVITE on the same
      // switchboard, which confuses the peer and prevents it from ever replying.
      final known = _knownContacts[normalized];
      final sha1d = (known?.avatarSha1d ?? '').trim();
      final activeKey = '$normalized|$sha1d';
      if (!_avatarInviteSent.contains(activeKey)) {
        _avatarSilentRequested.removeWhere((k) => k.startsWith('$normalized|'));
      }
      // On explicit force-refresh, clear the invite dedup so a new INVITE can
      // be sent even if the SHA1D hasn't changed.  Skip only when the INVITE
      // is already in-flight (active SB transfer for this contact).
      if (_sbP2pInFlightEmail != normalized) {
        _avatarInviteSent.removeWhere((k) => k.startsWith('$normalized|'));
        _avatarSilentRequested.removeWhere((k) => k.startsWith('$normalized|'));
      }
    }
    final known = _knownContacts[normalized];
    if (known == null) {
      return;
    }
    final sha1d = (known.avatarSha1d ?? '').trim();
    final msnObj = (known.avatarMsnObject ?? '').trim();
    if (sha1d.isEmpty || msnObj.isEmpty) {
      return;
    }
    _attemptHttpThenP2pAvatarFetch(
      contactEmail: normalized,
      avatarSha1d: sha1d,
      fullMsnObjectXml: msnObj,
    );
  }

  /// Add a contact to the forward/allow lists via ADL.
  void addContact(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@') || _socket == null) {
      return;
    }
    final parts = normalized.split('@');
    if (parts.length != 2) return;
    final local = _escapeXmlAttr(parts[0]);
    final domain = _escapeXmlAttr(parts[1]);
    // l="3" = Forward (1) + Allow (2)
    final payload =
        '<ml l="1"><d n="$domain"><c n="$local" l="3" t="1" /></d></ml>';
    _send(MsnpCommands.adl(_nextTrId(), payload));
    _log('ADL add-contact sent for $normalized');
    // Remember as known contact immediately so it shows in UI
    _rememberContact(email: normalized, displayName: normalized);
    // Emit contact event so providers update UI immediately
    _eventController.add(
      MsnpEvent(
        type: MsnpEventType.contact,
        command: 'ADL',
        from: normalized,
        body: normalized,
        raw: 'ADL $normalized',
      ),
    );
    // Persist to the address book via ABCH SOAP so the contact survives restarts.
    unawaited(_abchAddContact(normalized));
  }

  /// Persist a newly-added contact to the ABCH address book via SOAP.
  Future<void> _abchAddContact(String email) async {
    try {
      final ok = await _abchService.addContact(
        host: _connectedHost,
        ticket: _ticket,
        contactEmail: email,
        mspAuth: _mspAuth,
        mspProf: _mspProf,
        sid: _sid,
        log: (message) => _log(message),
      );
      if (ok) {
        _log('ABCH ABContactAdd succeeded for $email');
      } else {
        _log('ABCH ABContactAdd failed for $email (non-success response)');
      }
    } catch (e) {
      _log('ABCH ABContactAdd exception for $email: $e');
    }
  }

  /// Remove a contact from the forward/allow lists via RML.
  void removeContact(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@') || _socket == null) {
      return;
    }
    final parts = normalized.split('@');
    if (parts.length != 2) return;
    final local = _escapeXmlAttr(parts[0]);
    final domain = _escapeXmlAttr(parts[1]);
    // l="3" = Forward (1) + Allow (2) — same mask used for ADL
    final payload = '<ml><d n="$domain"><c n="$local" l="3" t="1" /></d></ml>';
    _send(MsnpCommands.rml(_nextTrId(), payload));
    _log('RML remove-contact sent for $normalized');
    // Remove from known contacts so UI updates immediately
    _knownContacts.remove(normalized);
    // Emit a contact event so providers rebuild and remove the contact from UI.
    _eventController.add(
      MsnpEvent(
        type: MsnpEventType.contact,
        command: 'RML',
        from: normalized,
        raw: 'RML $normalized',
      ),
    );
  }

  Future<void> sendTypingNotification({required String to}) async {
    final payload = StringBuffer()
      ..write('MIME-Version: 1.0\r\n')
      ..write('Content-Type: text/x-msmsgscontrol\r\n')
      ..write('TypingUser: $_email\r\n')
      ..write('\r\n');
    _sendToSwitchboard(
      to: to,
      payloadBytes: utf8.encode(payload.toString()),
      debugLabel: payload.toString(),
      fallbackToNotificationServer: false,
    );
  }

  Future<void> sendNudge({required String to}) async {
    final payload = StringBuffer()
      ..write('MIME-Version: 1.0\r\n')
      ..write('Content-Type: text/x-msnmsgr-datacast\r\n')
      ..write('\r\n')
      ..write('ID: 1\r\n');
    _sendToSwitchboard(
      to: to,
      payloadBytes: utf8.encode(payload.toString()),
      debugLabel: payload.toString(),
      fallbackToNotificationServer: true,
    );
  }

  /// Invites another contact into the current switchboard session (CAL).
  void inviteToSwitchboard(String email) {
    if (_sbSocket == null || !_sbReady) {
      _log('Cannot invite $email — no active switchboard session.');
      return;
    }
    _sendSb(MsnpCommands.cal(_nextSbTrId(), email));
    _log('CAL sent for $email');
  }

  // ── File transfer methods ──────────────────────────────────────────────

  /// Initiates a file transfer to [to] by sending an MSNSLP INVITE.
  /// Returns the session ID assigned to this transfer.
  int sendFileTransferInvite({
    required String to,
    required String fileName,
    required int fileSize,
  }) {
    final result = _fileTransferService.buildFileTransferInvite(
      contactEmail: to,
      myEmail: _email,
      fileName: fileName,
      fileSize: fileSize,
    );
    final mimeHeaders =
        'MIME-Version: 1.0\r\n'
        'Content-Type: application/x-msnmsgrp2p\r\n'
        'P2P-Dest: $to\r\n'
        'P2P-Src: $_email\r\n\r\n';
    final payload = <int>[...utf8.encode(mimeHeaders), ...result.bytes];
    _sendToSwitchboard(
      to: to,
      payloadBytes: payload,
      debugLabel: 'File INVITE → $to: $fileName ($fileSize bytes)',
      msgFlag: 'D',
      fallbackToNotificationServer: false,
    );
    _log(
      'File transfer INVITE sent to $to for $fileName (session=${result.session.sessionId})',
    );
    return result.session.sessionId;
  }

  /// Sends the actual file data in P2P chunks after receiving a 200 OK.
  Future<void> sendFileData({
    required int sessionId,
    required Uint8List fileBytes,
    required String to,
  }) async {
    final normalizedTo = to.trim().toLowerCase();
    final ftSession = _fileTransferService.getSession(sessionId);

    // Use consecutive baseIds (like the avatar transfer flow).
    final baseId = Random().nextInt(0x7fffffff);
    final prepBaseId = baseId;
    final dataBaseId = baseId + 1;
    final byeBaseId = baseId + 2;

    // ── Data-prep packet ────────────────────────────────────────────
    // WLM 2009 expects a 4-byte data-preparation frame before the
    // actual file data, just like for avatar transfers.
    final prepPayload = _slpService.buildDataPrepPacket(
      sessionId: sessionId,
      baseId: prepBaseId,
      footer: 2, // AppID 2 = file transfer
    );
    final mimePrep =
        'MIME-Version: 1.0\r\n'
        'Content-Type: application/x-msnmsgrp2p\r\n'
        'P2P-Dest: $to\r\n'
        'P2P-Src: $_email\r\n\r\n';
    // Queue the data-prep to trigger SB connection if needed.
    _sendToSwitchboard(
      to: to,
      payloadBytes: [...utf8.encode(mimePrep), ...prepPayload],
      debugLabel: 'File data-prep → $to session=$sessionId',
      msgFlag: 'D',
      fallbackToNotificationServer: false,
    );
    _log('Queued file data-prep for session=$sessionId');

    // Wait for switchboard to connect and flush the data-prep.
    for (var i = 0; i < 300; i++) {
      if (_sbReady && _sbSocket != null && _sbContactEmail == normalizedTo)
        break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!_sbReady || _sbSocket == null || _sbContactEmail != normalizedTo) {
      _log(
        'SB not ready after 30s for file transfer session=$sessionId — aborting',
      );
      _eventController.add(
        MsnpEvent(
          type: MsnpEventType.system,
          command: 'FTFAILED',
          from: normalizedTo,
          body: '$sessionId',
        ),
      );
      return;
    }

    // Wait for peer to process the data-prep.
    await Future<void>.delayed(const Duration(milliseconds: 80));

    // ── Send file data chunks directly (not via queue) ──────────────
    // Sending directly via _sendSbMsgPayload avoids all chunks being
    // queued and flushed at once by _flushSbQueue, ensuring the 10 ms
    // inter-chunk delay is honoured.
    for (final chunk in _fileTransferService.chunkFileForSending(
      sessionId: sessionId,
      fileBytes: fileBytes,
      baseId: dataBaseId,
    )) {
      if (!_sbReady || _sbSocket == null) {
        _log('SB lost during file transfer session=$sessionId — aborting');
        _eventController.add(
          MsnpEvent(
            type: MsnpEventType.system,
            command: 'FTFAILED',
            from: normalizedTo,
            body: '$sessionId',
          ),
        );
        return;
      }
      final mimeHeaders =
          'MIME-Version: 1.0\r\n'
          'Content-Type: application/x-msnmsgrp2p\r\n'
          'P2P-Dest: $to\r\n'
          'P2P-Src: $_email\r\n\r\n';
      _sendSbMsgPayload([...utf8.encode(mimeHeaders), ...chunk], msgFlag: 'D');
      // Yield between chunks to let the SB relay flush and avoid
      // overwhelming the peer.  30 ms matches WLM 2009's observed pace.
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    _log(
      'File data fully sent for session=$sessionId (${fileBytes.length} bytes)',
    );

    // ── Wait for peer's data-complete ACK, then send BYE ────────────
    // WLM 2009's P2P state machine requires the sender to close the
    // session with a BYE after all data has been transferred.  We wait
    // for the peer's data-complete ACK (Flags=0x02) before sending BYE
    // so WLM has processed all chunks before we signal completion.
    final ackCompleter = Completer<void>();
    // Key the completer on the data baseId so the ACK matcher can
    // distinguish the data-complete ACK from the data-prep ACK.
    _ftDataAckCompleters[dataBaseId] = ackCompleter;
    try {
      await ackCompleter.future.timeout(const Duration(seconds: 15));
      _log('Data-complete ACK received for session=$sessionId — sending BYE');
    } catch (_) {
      _log(
        'Timed out waiting for data-complete ACK session=$sessionId — sending BYE anyway',
      );
    }
    _ftDataAckCompleters.remove(dataBaseId);

    if (_sbReady && _sbSocket != null && ftSession != null) {
      final byeSlp = [
        'BYE MSNMSGR:$normalizedTo MSNSLP/1.0',
        'To: <msnmsgr:$normalizedTo>',
        'From: <msnmsgr:$_email>',
        'Via: MSNSLP/1.0/TLP ;branch=${ftSession.branchId}',
        'CSeq: 0',
        'Call-ID: ${ftSession.callId}',
        'Max-Forwards: 0',
        'Content-Type: application/x-msnmsgr-sessionclosebody',
        'Content-Length: 0',
        '',
        '',
      ].join('\r\n');
      final byePayload = _slpService.buildP2pPayload(0, byeBaseId, 0, byeSlp);
      final mimeBye =
          'MIME-Version: 1.0\r\n'
          'Content-Type: application/x-msnmsgrp2p\r\n'
          'P2P-Dest: $normalizedTo\r\n'
          'P2P-Src: $_email\r\n\r\n';
      _sendSbMsgPayload(
        [...utf8.encode(mimeBye), ...byePayload],
        debugLabel: 'File BYE → $normalizedTo session=$sessionId',
        msgFlag: 'D',
      );
      _log('Sent file transfer BYE to $normalizedTo session=$sessionId');
    }

    // Clean up the outbound session — it's done.
    _fileTransferService.removeSession(sessionId);

    // Notify UI that outbound transfer completed.
    _eventController.add(
      MsnpEvent(
        type: MsnpEventType.system,
        command: 'FTCOMPLETE',
        from: normalizedTo,
        body: '$sessionId',
      ),
    );
  }

  /// Accept an incoming file transfer (send 200 OK).
  void acceptFileTransfer({required int sessionId, required String from}) {
    final acceptBytes = _fileTransferService.buildAcceptResponse(
      sessionId: sessionId,
      myEmail: _email,
      peerEmail: from,
    );
    if (acceptBytes.isEmpty) return;
    final mimeHeaders =
        'MIME-Version: 1.0\r\n'
        'Content-Type: application/x-msnmsgrp2p\r\n'
        'P2P-Dest: $from\r\n'
        'P2P-Src: $_email\r\n\r\n';
    final payload = <int>[...utf8.encode(mimeHeaders), ...acceptBytes];
    _sendToSwitchboard(
      to: from,
      payloadBytes: payload,
      debugLabel: 'File 200 OK → $from session=$sessionId',
      msgFlag: 'D',
      fallbackToNotificationServer: false,
    );
    _log('File transfer accepted: session=$sessionId from=$from');
  }

  /// Decline an incoming file transfer (send 603 Decline).
  void declineFileTransfer({required int sessionId, required String from}) {
    final declineBytes = _fileTransferService.buildDeclineResponse(
      sessionId: sessionId,
      myEmail: _email,
      peerEmail: from,
    );
    if (declineBytes.isEmpty) return;
    final mimeHeaders =
        'MIME-Version: 1.0\r\n'
        'Content-Type: application/x-msnmsgrp2p\r\n'
        'P2P-Dest: $from\r\n'
        'P2P-Src: $_email\r\n\r\n';
    final payload = <int>[...utf8.encode(mimeHeaders), ...declineBytes];
    _sendToSwitchboard(
      to: from,
      payloadBytes: payload,
      debugLabel: 'File 603 Decline → $from session=$sessionId',
      msgFlag: 'D',
      fallbackToNotificationServer: false,
    );
    _log('File transfer declined: session=$sessionId from=$from');
  }

  Future<void> disconnect() async {
    _stopKeepAlive();
    _stopSbQueueWatchdog();
    await _disconnectSwitchboard();
    if (_socket != null) {
      _send(MsnpCommands.out());
      await _socket!.close();
      _socket = null;
    }
    _statusController.add(ConnectionStatus.disconnected);
  }

  void dispose() {
    _stopKeepAlive();
    _stopSbQueueWatchdog();
    unawaited(_disconnectSwitchboard());
    _socket?.destroy();
    _eventController.close();
    _statusController.close();
    _fileTransferService.dispose();
  }

  int _nextTrId() {
    _trId += 1;
    return _trId;
  }

  void _send(String command) {
    _logTx(command);
    _sendRaw(utf8.encode(command));
  }

  void _sendRaw(List<int> bytes) {
    final socket = _socket;
    if (socket == null) {
      return;
    }
    try {
      socket.add(bytes);
    } on SocketException catch (error) {
      _log('Send failed on NS socket: $error');
      _socket = null;
    } catch (error) {
      _log('Unexpected NS send failure: $error');
      _socket = null;
    }
  }

  void _sendMsgPayload(String payload) {
    final payloadBytes = utf8.encode(payload);
    final header = 'MSG ${_nextTrId()} N ${payloadBytes.length}\r\n';
    _logTx('$header$payload');
    final frame = <int>[...ascii.encode(header), ...payloadBytes];
    _sendRaw(frame);
  }

  void _sendToSwitchboard({
    required String to,
    required List<int> payloadBytes,
    String? debugLabel,
    String msgFlag = 'N',
    required bool fallbackToNotificationServer,
  }) {
    final normalizedTo = to.trim().toLowerCase();
    if (normalizedTo.isEmpty) {
      return;
    }

    _sbIsSilentAvatarSession = false;

    if (_sbReady && _sbSocket != null && _sbContactEmail == normalizedTo) {
      _sendSbMsgPayload(payloadBytes, debugLabel: debugLabel, msgFlag: msgFlag);
      return;
    }

    final msg = _PendingOutboundMessage(
      to: normalizedTo,
      payloadBytes: payloadBytes,
      debugLabel: debugLabel,
      msgFlag: msgFlag,
      fallbackToNotificationServer: fallbackToNotificationServer,
    );

    // Chat messages (non-'D') get priority over binary P2P data to avoid
    // noticeable input lag when a large file or avatar transfer is in
    // progress.  Insert them before the first P2P-flagged entry.
    if (msgFlag.toUpperCase() != 'D') {
      final firstP2p = _sbOutboundQueue.indexWhere(
        (m) => m.msgFlag.toUpperCase() == 'D',
      );
      if (firstP2p >= 0) {
        _sbOutboundQueue.insert(firstP2p, msg);
      } else {
        _sbOutboundQueue.add(msg);
      }
    } else {
      _sbOutboundQueue.add(msg);
    }
    _ensureOutboundSwitchboard(normalizedTo, bypassP2pLock: msgFlag != 'D');
  }

  void _ensureOutboundSwitchboard(
    String recipient, {
    bool bypassP2pLock = false,
  }) {
    if (_sbConnecting || _sbAwaitingXfr) {
      return;
    }

    if (_sbSocket != null && _sbContactEmail == recipient) {
      return;
    }

    // Do NOT tear down the active SB while a P2P INVITE is in-flight for a
    // different contact.  The 200 OK (and subsequent data) still needs to
    // arrive on that socket.  The request will be retried automatically when
    // the current transfer ends via _tryNextPendingAvatar().
    if (!bypassP2pLock &&
        _sbP2pInFlightEmail != null &&
        _sbP2pInFlightEmail != recipient) {
      _log(
        'P2P in-flight for $_sbP2pInFlightEmail — deferring SB request for $recipient',
      );
      return;
    }

    // Guard against a duplicate XFR for the same recipient (can happen when
    // _tryNextPendingAvatar fires from multiple sources in quick succession).
    if (_pendingXfrRequests.containsValue(recipient)) {
      _log('XFR already pending for $recipient — skipping duplicate request.');
      return;
    }

    _sbPendingRecipient = recipient;
    _sbAwaitingXfr = true;
    _sbXfrTimeout?.cancel();
    _sbXfrTimeout = Timer(const Duration(seconds: 8), () {
      _log('XFR response timeout for $recipient — resetting.');
      _sbAwaitingXfr = false;
      _pendingXfrRequests.removeWhere((_, v) => v == recipient);
      _markAvatarFetchFailed(recipient, reason: 'XFR timeout');
    });
    final trId = _nextTrId();
    _pendingXfrRequests[trId] = recipient;
    _send('XFR $trId SB\r\n');
    if (_sbIsSilentAvatarSession) {
      _log(
        'Requested silent switchboard endpoint for avatar recipient $recipient.',
      );
    } else {
      _log('Requested switchboard endpoint for recipient $recipient.');
    }
  }

  int _nextSbTrId() {
    _sbTrId += 1;
    return _sbTrId;
  }

  Future<void> _connectSwitchboard({
    required String host,
    required int port,
    required String authToken,
    required bool inviteMode,
    required String sessionId,
    required String contactEmail,
  }) async {
    _sbConnecting = true;

    try {
      await _disconnectSwitchboard();

      _sbHost = host;
      _sbPort = port;
      _sbAuthToken = authToken;
      _sbSessionId = sessionId;
      _sbContactEmail = contactEmail.toLowerCase();
      _sbIsInviteMode = inviteMode;
      if (!inviteMode && _sbPendingRecipient != null) {
        _sbIsSilentAvatarSession = _avatarInvitePending.contains(
          _sbPendingRecipient!,
        );
      }
      _sbReady = false;
      _sbTrId = 0;
      _sbPendingFrame = null;
      _sbRxBuffer.clear();

      _log(
        'Connecting switchboard socket to $host:$port for ${_sbContactEmail!}.',
      );
      _sbSocket = await Socket.connect(
        host,
        port,
        timeout: ServerConfig.connectTimeout,
      );
      _sbSocket!.listen(
        _onSbData,
        onDone: _onSbDone,
        onError: _onSbError,
        cancelOnError: false,
      );

      if (inviteMode) {
        _sendSb('ANS ${_nextSbTrId()} $_email $authToken $sessionId\r\n');
      } else {
        _sendSb('USR ${_nextSbTrId()} $_email $authToken\r\n');
      }
    } on Object catch (error) {
      _log('Failed to connect switchboard socket: $error');
      _sbReady = false;
    } finally {
      _sbConnecting = false;
    }
  }

  Future<void> _disconnectSwitchboard() async {
    try {
      if (_sbSocket != null) {
        _sbSocket!.destroy();
      }
    } finally {
      _cancelSbJoinTimeout();
      _sbXfrTimeout?.cancel();
      _sbXfrTimeout = null;
      _sbSocket = null;
      _sbPendingFrame = null;
      _sbRxBuffer.clear();
      _sbReady = false;
      _sbConnecting = false;
      _sbIsInviteMode = false;
      _sbIsSilentAvatarSession = false;
      _sbSessionId = null;
      _sbAuthToken = null;
      _sbHost = null;
      _sbPort = null;
      _sbContactEmail = null;
    }
  }

  void _sendSb(String command) {
    _logTx('[SB] $command');
    final socket = _sbSocket;
    if (socket == null) {
      return;
    }
    try {
      socket.add(utf8.encode(command));
    } on SocketException catch (error) {
      _log('Send failed on SB socket: $error');
      _sbSocket = null;
      _sbReady = false;
    } catch (error) {
      _log('Unexpected SB send failure: $error');
      _sbSocket = null;
      _sbReady = false;
    }
  }

  void _sendSbMsgPayload(
    List<int> payloadBytes, {
    String? debugLabel,
    String msgFlag = 'N',
  }) {
    final flag = (msgFlag.toUpperCase() == 'D') ? 'D' : 'N';
    final commandStr = 'MSG ${_nextSbTrId()} $flag ${payloadBytes.length}\r\n';
    if (debugLabel != null && debugLabel.isNotEmpty) {
      _logTx('[SB] $commandStr$debugLabel');
    } else {
      _logTx('[SB] $commandStr<binary:${payloadBytes.length}>');
    }
    final socket = _sbSocket;
    if (socket == null) {
      return;
    }
    try {
      socket.add(utf8.encode(commandStr));
      socket.add(payloadBytes);
    } on SocketException catch (error) {
      _log('Send failed on SB MSG payload: $error');
      _sbSocket = null;
      _sbReady = false;
    } catch (error) {
      _log('Unexpected SB MSG send failure: $error');
      _sbSocket = null;
      _sbReady = false;
    }
  }

  void _onSbData(List<int> data) {
    _sbRxBuffer.addAll(data);

    while (true) {
      if (_sbPendingFrame != null) {
        final pending = _sbPendingFrame!;
        if (_sbRxBuffer.length < pending.length) {
          return;
        }

        final payloadBytes = _sbRxBuffer.sublist(0, pending.length);
        _sbRxBuffer.removeRange(0, pending.length);
        final payload = utf8.decode(payloadBytes, allowMalformed: true);
        _handleSbPayload(pending, payload, payloadBytes);
        _sbPendingFrame = null;
        _trimLeadingSbCrlf();
        continue;
      }

      final splitIndex = _indexOfCrlf(_sbRxBuffer);
      if (splitIndex == -1) {
        return;
      }

      final lineBytes = _sbRxBuffer.sublist(0, splitIndex);
      _sbRxBuffer.removeRange(0, splitIndex + 2);
      final line = utf8.decode(lineBytes, allowMalformed: true);
      if (line.isEmpty) {
        continue;
      }

      _logRx('[SB] $line');
      final pendingLength = _extractPayloadLength(line);
      if (pendingLength != null) {
        _handleSbLine(line);
        _sbPendingFrame = _PendingFrame.fromHeader(
          headerLine: line,
          length: pendingLength,
          defaultTo: _email,
        );
        continue;
      }

      _handleSbLine(line);
    }
  }

  void _handleSbLine(String line) {
    final parts = line.trim().split(' ');
    if (parts.isEmpty) {
      return;
    }

    final command = parts.first.toUpperCase();
    if (command == 'JOI' && parts.length > 1) {
      _cancelSbJoinTimeout();
      final email = parts[1].toLowerCase();
      _sbContactEmail = email;
      if (email.contains('@')) {
        _rememberContact(
          email: email,
          displayName: email,
          status: PresenceStatus.online,
        );
        _eventController.add(
          const MsnpEvent(type: MsnpEventType.system, command: 'SBPRES'),
        );
      }
      _sbReady = true;
      _flushSbQueue();
      _trySendPendingAvatarInviteFor(email);
      return;
    }

    if (command == 'IRO' && parts.length > 3) {
      _cancelSbJoinTimeout();
      final email = parts[3].toLowerCase();
      _sbContactEmail = email;
      if (email.contains('@')) {
        _rememberContact(
          email: email,
          displayName: email,
          status: PresenceStatus.online,
        );
        _eventController.add(
          const MsnpEvent(type: MsnpEventType.system, command: 'SBPRES'),
        );
      }
      if (_sbIsInviteMode) {
        _sbReady = true;
        _flushSbQueue();
        _trySendPendingAvatarInviteFor(email);
      }
      return;
    }

    if (command == 'ANS' || command == 'USR') {
      if (command == 'ANS' && _sbIsInviteMode) {
        _sbReady = true;
        _flushSbQueue();
        return;
      }

      _sbReady = false;
      if (command == 'USR' && !_sbIsInviteMode && _sbPendingRecipient != null) {
        _sendSb('CAL ${_nextSbTrId()} ${_sbPendingRecipient!}\r\n');
        if (_sbIsSilentAvatarSession) {
          _startSbJoinTimeout(_sbPendingRecipient!);
        }
      }
      return;
    }

    if (command == 'BYE' && parts.length > 1) {
      final who = parts[1].toLowerCase();
      _log('Switchboard peer left session: $who');
      _sbReady = false;
      if (who.contains('@')) {
        _rememberContact(
          email: who,
          displayName: who,
          status: PresenceStatus.appearOffline,
        );
        _eventController.add(
          const MsnpEvent(type: MsnpEventType.system, command: 'SBPRES'),
        );
      }
    }
  }

  void _handleSbPayload(
    _PendingFrame frame,
    String payload,
    List<int> payloadBytes,
  ) {
    if (frame.command != 'MSG') {
      return;
    }

    final from = (frame.from ?? _sbContactEmail ?? 'unknown').toLowerCase();
    print(
      '[MSNSLP][SB-RX] MSG from=$from len=${payloadBytes.length} isP2p=${_slpService.isP2pPayloadBytes(payloadBytes)}',
    );
    if (from.contains('@')) {
      _rememberContact(
        email: from,
        displayName: from,
        status: PresenceStatus.online,
      );
      _eventController.add(
        const MsnpEvent(type: MsnpEventType.system, command: 'SBPRES'),
      );
    }
    if (_slpService.isP2pPayloadBytes(payloadBytes)) {
      final frameInfo = _slpService.parseInboundP2pFrame(payloadBytes);
      if (frameInfo != null) {
        // Mask off WLM high bit early so we can decide what to log.
        final lowFlags = frameInfo.flags & 0x00FFFFFF;
        final isDataChunk = (lowFlags & 0x20) != 0;
        final isCloseSubStream = (lowFlags & 0x40) != 0 && !isDataChunk;

        // For data chunks, don't dump binary slpText (it's raw image bytes).
        print(
          '[MSNSLP][RX] from=$from Session=${frameInfo.sessionId} '
          'BaseID=${frameInfo.baseId} Flags=0x${frameInfo.flags.toRadixString(16)} '
          'Offset=${frameInfo.offset} MsgSize=${frameInfo.messageSize} '
          'TotalSize=${frameInfo.totalSize}'
          '${(isDataChunk || isCloseSubStream) ? '' : '\n${frameInfo.slpText}'}',
        );

        // ── ACK logic ────────────────────────────────────────────────────────
        // lowFlags and isDataChunk already computed above.

        // ACK SLP messages and data-prep packets only:
        //   0x00 = SLP text (INVITE / 200 OK / BYE) or data-prep (4-byte)
        //   0x01 = SLP variant on some bridges
        // We do NOT ACK: 0x02 (ACK), 0x04 (control), data chunks.
        final shouldAck =
            !isDataChunk && (lowFlags == 0x00 || lowFlags == 0x01);

        // Log file transfer data-prep receipt for diagnostics.
        if (shouldAck &&
            frameInfo.sessionId != 0 &&
            frameInfo.messageSize == 4 &&
            frameInfo.totalSize == 4) {
          final ftSess = _fileTransferService.getSession(frameInfo.sessionId);
          print(
            '[FT] Data-prep received from $from session=${frameInfo.sessionId}'
            ' ftSession=${ftSess != null ? 'found' : 'NOT FOUND'}',
          );
        }

        if (shouldAck && frameInfo.messageSize > 0) {
          final ackBytes = _slpService.buildAckBinary(
            incomingSessionId: frameInfo.sessionId,
            incomingBaseId: frameInfo.baseId,
            // Pass the full TotalSize so the ACK mirrors what WLM sends.
            ackedTotalSize: frameInfo.totalSize > 0
                ? frameInfo.totalSize
                : frameInfo.messageSize,
          );
          final mimeHeaders =
              'MIME-Version: 1.0\r\n'
              'Content-Type: application/x-msnmsgrp2p\r\n'
              'P2P-Dest: $from\r\n'
              'P2P-Src: $_email\r\n\r\n';
          final ackPayload = <int>[...utf8.encode(mimeHeaders), ...ackBytes];
          _sendSbMsgPayload(
            ackPayload,
            debugLabel: 'P2P ACK flags=0x02 ackSess=${frameInfo.sessionId}',
            msgFlag: 'D',
          );
          print(
            '[MSNSLP][TX] ACK → $from session=${frameInfo.sessionId} baseId=${frameInfo.baseId}',
          );
        }

        // ── Route by Flags ───────────────────────────────────────────────────
        final slp = frameInfo.slpText;
        // Only log SLP text for non-data frames (data chunks are binary noise).
        if (slp.isNotEmpty && !isDataChunk && !isCloseSubStream) {
          print('[MSNSLP][RX] SLP text from $from:\n$slp');
        }

        // Flags=0x02 means the peer acknowledged our INVITE transport packet.
        // Use lowFlags to tolerate WLM's high-bit (0x1000000).
        if (lowFlags == 0x02) {
          _p2pSessionManager.updateStatus(
            from,
            'P2P: Peer acknowledged INVITE — waiting for 200 OK',
          );
          // Complete any pending data-complete ACK waiter for file transfers.
          // Match on ackUniqueId (the baseId of the acked message) to avoid
          // confusing a data-prep ACK with the data-complete ACK.
          for (final entry in _ftDataAckCompleters.entries.toList()) {
            if (!entry.value.isCompleted &&
                (frameInfo.ackUniqueId == entry.key ||
                    frameInfo.sessionId == entry.key)) {
              print(
                '[FT] Data-complete ACK received for key=${entry.key} '
                'ackUniqueId=${frameInfo.ackUniqueId} session=${frameInfo.sessionId}',
              );
              _ftDataAckCompleters.remove(entry.key);
              entry.value.complete();
              break;
            }
          }
        }

        // Flags=0x04 is a NAK — log which message the peer is NAK-ing.
        if ((lowFlags & 0x04) != 0) {
          print(
            '[MSNSLP][NAK] from=$from Flags=0x${frameInfo.flags.toRadixString(16)} '
            'AckSess=${frameInfo.ackSessionId} AckBaseId=${frameInfo.ackUniqueId} '
            'Session=${frameInfo.sessionId} BaseID=${frameInfo.baseId}',
          );
        }

        // Flags=0x40 = close sub-stream (P2P session close from peer).
        // ACK it so the peer knows we received the close signal.
        if (isCloseSubStream) {
          print(
            '[MSNSLP] Close sub-stream (0x40) from $from session=${frameInfo.sessionId}',
          );
          final ackBytes = _slpService.buildAckBinary(
            incomingSessionId: frameInfo.sessionId,
            incomingBaseId: frameInfo.baseId,
            ackedTotalSize: frameInfo.totalSize,
          );
          final mimeHeaders =
              'MIME-Version: 1.0\r\n'
              'Content-Type: application/x-msnmsgrp2p\r\n'
              'P2P-Dest: $from\r\n'
              'P2P-Src: $_email\r\n\r\n';
          _sendSbMsgPayload(
            [...utf8.encode(mimeHeaders), ...ackBytes],
            debugLabel: 'ACK close sub-stream session=${frameInfo.sessionId}',
            msgFlag: 'D',
          );
          print(
            '[MSNSLP][TX] ACK close sub-stream → $from session=${frameInfo.sessionId}',
          );
        }

        if (isDataChunk) {
          // Data chunk — route to the correct session manager.
          final split = _splitP2pBody(payloadBytes);

          // Check if this session belongs to a file transfer
          final ftSession = _fileTransferService.getSession(
            frameInfo.sessionId,
          );
          if (ftSession != null) {
            print(
              '[FT] Data chunk: session=${frameInfo.sessionId} '
              'offset=${frameInfo.offset} msgSize=${frameInfo.messageSize} '
              'total=${frameInfo.totalSize} '
              'progress=${ftSession.bytesTransferred}/${ftSession.fileSize}',
            );
            unawaited(
              _fileTransferService.handleDataChunk(
                sessionId: frameInfo.sessionId,
                offset: frameInfo.offset,
                messageSize: frameInfo.messageSize,
                totalSize: frameInfo.totalSize,
                rawP2pBytes: split,
              ),
            );
          } else {
            // Default: avatar P2P session
            unawaited(
              _p2pSessionManager.handleDataChunk(
                sessionId: frameInfo.sessionId,
                offset: frameInfo.offset,
                messageSize: frameInfo.messageSize,
                totalSize: frameInfo.totalSize,
                peerEmail: from,
                rawP2pBytes: split,
              ),
            );
            // Reset stall timer – data is still flowing.
            final normFrom = from.toLowerCase().trim();
            final existingTimer = _avatarStallTimers[normFrom];
            if (existingTimer != null) {
              existingTimer.cancel();
              final stallSessionId = frameInfo.sessionId;
              _avatarStallTimers[normFrom] = Timer(
                const Duration(seconds: 20),
                () {
                  _log('Avatar P2P stall for $normFrom – aborting');
                  _avatarStallTimers.remove(normFrom);
                  // Close the leaked P2P session so the buffer doesn't linger.
                  _p2pSessionManager.closeSession(stallSessionId);
                  _clearP2pInFlight(normFrom);
                  // Re-queue for retry instead of permanently failing — the peer
                  // may have just been slow.
                  _avatarInvitePending.add(normFrom);
                  _avatarInviteSent.removeWhere(
                    (k) => k.startsWith('$normFrom|'),
                  );
                  _avatarSilentRequested.removeWhere(
                    (k) => k.startsWith('$normFrom|'),
                  );
                  _log(
                    'Re-queued avatar fetch for $normFrom after data stall.',
                  );
                  _tryNextPendingAvatar();
                },
              );
            }
          }

          // Send a single ACK only after the LAST data chunk completes the
          // transfer.  In P2P v1 individual chunks are NOT acked — only the
          // final assembled message gets a binary ACK.
          if (frameInfo.totalSize > 0 &&
              frameInfo.offset + frameInfo.messageSize >= frameInfo.totalSize) {
            final ackBytes = _slpService.buildAckBinary(
              incomingSessionId: frameInfo.sessionId,
              incomingBaseId: frameInfo.baseId,
              ackedTotalSize: frameInfo.totalSize,
            );
            final mimeHeaders =
                'MIME-Version: 1.0\r\n'
                'Content-Type: application/x-msnmsgrp2p\r\n'
                'P2P-Dest: $from\r\n'
                'P2P-Src: $_email\r\n\r\n';
            final ackPayload = <int>[...utf8.encode(mimeHeaders), ...ackBytes];
            _sendSbMsgPayload(
              ackPayload,
              debugLabel:
                  'P2P data-complete ACK session=${frameInfo.sessionId}',
              msgFlag: 'D',
            );
            print(
              '[MSNSLP][TX] Data-complete ACK → $from session=${frameInfo.sessionId}',
            );
          }
        } else if (slp.startsWith('MSNSLP/1.0 ')) {
          final statusLine = slp.split('\r\n').first;
          final statusParts = statusLine.split(' ');
          final statusCode = statusParts.length >= 2
              ? int.tryParse(statusParts[1])
              : null;
          if (statusCode == 200) {
            _avatarBackgroundFailed.remove(from);
            _p2pSessionManager.updateStatus(
              from,
              'P2P: Negotiating session...',
            );
            // Cancel the 200 OK wait-timer — we got the response.  Keep the
            // in-flight lock active until the actual data transfer completes.
            _sbP2pResponseTimeout?.cancel();
            _sbP2pResponseTimeout = null;
            print(
              '[MSNSLP] 200 OK received from $from — proceeding to data transfer',
            );
            // Extract SessionID and TotalSize from the 200 OK body.
            // WLM 2009 uses "TotalSize"; older builds use "DataSize". Fall back
            // to the P2P binary sessionId/totalSize if the body fields are absent.
            final bodySessionId = _extractSlpBodyField(slp, 'SessionID');
            final bodySize =
                _extractSlpBodyField(slp, 'TotalSize') ??
                _extractSlpBodyField(slp, 'DataSize');
            final sessId =
                int.tryParse(bodySessionId ?? '') ?? frameInfo.sessionId;
            final totalSize = int.tryParse(bodySize ?? '') ?? 0;

            // ── Send SLP-level text ACK ─────────────────────────────────────
            // This is required by the MSNSLP SIP handshake and is separate from
            // the binary Flags=0x08 transport ACK already sent above.
            final inviteParams = _p2pSessionManager.getInviteParams(from);
            if (inviteParams != null) {
              final slpAckBinary = _slpService.buildSlpAckPacket(
                myEmail: _email,
                peerEmail: from,
                callId: inviteParams.callId,
                branchId: inviteParams.branchId,
                sessionId: inviteParams.sessionId,
                baseId: inviteParams.baseId,
              );
              final ackMimeHeaders =
                  'MIME-Version: 1.0\r\n'
                  'Content-Type: application/x-msnmsgrp2p\r\n'
                  'P2P-Dest: $from\r\n'
                  'P2P-Src: $_email\r\n\r\n';
              final slpAckPayload = <int>[
                ...utf8.encode(ackMimeHeaders),
                ...slpAckBinary,
              ];
              _sendSbMsgPayload(
                slpAckPayload,
                debugLabel:
                    'SLP text ACK to $from callId=${inviteParams.callId}',
                msgFlag: 'D',
              );
              print(
                '[MSNSLP][TX] SLP text ACK → $from  callId=${inviteParams.callId}',
              );
            } else {
              _log(
                'WARNING: no invite params for $from — SLP text ACK not sent',
              );
            }

            // Open the reassembly buffer now that we know the total size.
            // But first check if this belongs to an outbound file transfer —
            // if so, the peer accepted our file and we should start sending data.
            final ftSession = _fileTransferService.getSession(sessId);
            if (ftSession != null && ftSession.isOutgoing) {
              print(
                '[MSNSLP] File transfer 200 OK for session $sessId — peer accepted',
              );
              _eventController.add(
                MsnpEvent(
                  type: MsnpEventType.system,
                  command: 'FTACCEPTED',
                  from: from,
                  body: '$sessId',
                ),
              );
            } else if (sessId > 0) {
              _p2pSessionManager.openSession(
                sessionId: sessId,
                peerEmail: from,
                totalSize: totalSize,
              );
            }
          } else if (statusCode == 603 || statusCode == 500) {
            _markAvatarFetchFailed(from, reason: 'MSNSLP $statusCode response');
          } else {
            print('[MSNSLP] Unexpected SLP response $statusCode from $from');
            _markAvatarFetchFailed(from, reason: 'MSNSLP $statusCode response');
          }
        } else if (slp.startsWith('INVITE ')) {
          // The peer is sending us an INVITE — most commonly a transport
          // negotiation request (transreqbody) or a session request for our DP.
          _handleIncomingSlpInvite(
            from,
            slp,
            inviteBaseId: frameInfo.baseId,
            inviteTotalSize: frameInfo.totalSize,
          );
        } else if (slp.startsWith('BYE ')) {
          // Peer is closing a P2P session.
          final byeCallId = _extractSlpHeader(slp, 'Call-ID') ?? '';
          print('[MSNSLP] BYE from $from callId=$byeCallId');
          final ftSession = _fileTransferService.getSessionByCallId(byeCallId);
          if (ftSession != null) {
            if (ftSession.isOutgoing) {
              // The RECEIVER sent BYE — this is the normal close signal for
              // file transfers. ACK the BYE and clean up.
              print(
                '[MSNSLP] Outbound file transfer session ${ftSession.sessionId} '
                'closed by receiver BYE — transfer successful',
              );
            } else if (ftSession.isComplete) {
              print(
                '[MSNSLP] Inbound file transfer session ${ftSession.sessionId} '
                'closed by peer BYE',
              );
            }
          }
        }
      } else {
        print('[MSNSLP][RX] unparseable frame\n$payload');
      }
      return;
    }

    final event = MsnpParser.parseMsgPayload(
      from: from,
      to: _email,
      payload: payload,
    );
    _eventController.add(event);
  }

  void _flushSbQueue() {
    if (!_sbReady || _sbSocket == null) {
      return;
    }

    final activePeer = _sbContactEmail;
    if (activePeer == null || activePeer.isEmpty) {
      return;
    }

    final sent = <_PendingOutboundMessage>[];
    for (final pending in _sbOutboundQueue) {
      if (pending.to != activePeer) {
        continue;
      }
      _sendSbMsgPayload(
        pending.payloadBytes,
        debugLabel: pending.debugLabel,
        msgFlag: pending.msgFlag,
      );
      sent.add(pending);
    }
    for (final item in sent) {
      _sbOutboundQueue.remove(item);
    }

    // Keep this switchboard pinned to the active peer until server closes it.
    // Remaining recipients are handled on next SB session from _onSbDone.
  }

  void _trimLeadingSbCrlf() {
    while (_sbRxBuffer.length >= 2 &&
        _sbRxBuffer[0] == 13 &&
        _sbRxBuffer[1] == 10) {
      _sbRxBuffer.removeRange(0, 2);
    }
  }

  void _handleRng(String line) {
    final parts = line.trim().split(' ');
    if (parts.length < 7) {
      _log('Received malformed RNG: $line');
      return;
    }

    // RNG is an incoming switchboard request from a peer (e.g. to request our
    // avatar or send us messages).  We should accept it even if we have an
    // outbound avatar fetch pending — the outbound fetch can be retried later,
    // but the peer will give up if we never accept the RNG.
    if (_sbP2pInFlightEmail != null ||
        _sbAwaitingXfr ||
        _sbIsSilentAvatarSession) {
      _log(
        'Accepting RNG from ${parts[5]} — cancelling outbound avatar pipeline.',
      );
      // Abort whatever the avatar pipeline was doing.
      final inFlight = _sbP2pInFlightEmail;
      if (inFlight != null) {
        _clearP2pInFlight(inFlight);
        // Re-queue the interrupted contact so its avatar is retried after the
        // RNG switchboard closes.  Clear its dedup keys so the retry actually
        // issues a fresh XFR + INVITE.
        _avatarInvitePending.add(inFlight);
        _avatarInviteSent.removeWhere((k) => k.startsWith('$inFlight|'));
        _avatarSilentRequested.removeWhere((k) => k.startsWith('$inFlight|'));
        // Close any half-received P2P sessions for this contact so stale
        // buffers don't interfere with the retry.
        _p2pSessionManager.closeAllSessionsForPeer(inFlight);
        _log('Re-queued avatar fetch for $inFlight after RNG interrupt.');
      }
      _sbAwaitingXfr = false;
      _sbXfrTimeout?.cancel();
      _sbXfrTimeout = null;
      _sbIsSilentAvatarSession = false;
      _cancelSbJoinTimeout();
      // Tear down the existing SB so _connectSwitchboard can start fresh.
      _handledAvatarSessionIds.clear();
      _sbSocket?.destroy();
      _sbSocket = null;
      _sbReady = false;
      _sbConnecting = false;
      _sbAuthToken = null;
      _sbHost = null;
      _sbPort = null;
      _sbSessionId = null;
      _sbContactEmail = null;
      _sbPendingRecipient = null;
      _sbPendingFrame = null;
      _sbRxBuffer.clear();
      _deferredRngLines.clear();
    }

    final sessionId = parts[1];
    final hostPort = parts[2];
    final authToken = parts[4];
    final contactEmail = parts[5].toLowerCase();
    _rememberContact(
      email: contactEmail,
      displayName: contactEmail,
      status: PresenceStatus.online,
    );
    _eventController.add(
      const MsnpEvent(type: MsnpEventType.system, command: 'SBPRES'),
    );
    final hostParts = hostPort.split(':');
    if (hostParts.length != 2) {
      _log('RNG host:port invalid: $hostPort');
      return;
    }

    final host = hostParts[0];
    final port = int.tryParse(hostParts[1]);
    if (port == null) {
      _log('RNG port invalid: $hostPort');
      return;
    }

    unawaited(
      _connectSwitchboard(
        host: host,
        port: port,
        authToken: authToken,
        inviteMode: true,
        sessionId: sessionId,
        contactEmail: contactEmail,
      ),
    );
  }

  void _handleXfr(String line) {
    final parts = line.trim().split(' ');
    if (parts.length < 6) {
      _sbAwaitingXfr = false;
      _log('Received malformed XFR: $line');
      return;
    }

    final trId = int.tryParse(parts[1]);
    if (trId == null) {
      _log('Received XFR with invalid transaction id: $line');
      return;
    }

    if (parts[2].toUpperCase() != 'SB') {
      _pendingXfrRequests.remove(trId);
      if (_pendingXfrRequests.isEmpty) {
        _sbAwaitingXfr = false;
      }
      return;
    }

    final hostPort = parts[3];
    final authToken = parts[5];
    final hostParts = hostPort.split(':');
    final recipient = _pendingXfrRequests.remove(trId);
    if (hostParts.length != 2 || recipient == null || recipient.isEmpty) {
      if (_pendingXfrRequests.isEmpty) {
        _sbAwaitingXfr = false;
      }
      _log('Unable to use XFR for switchboard: $line');
      return;
    }

    final port = int.tryParse(hostParts[1]);
    if (port == null) {
      if (_pendingXfrRequests.isEmpty) {
        _sbAwaitingXfr = false;
      }
      _log('XFR provided invalid port: $hostPort');
      return;
    }

    _sbPendingRecipient = recipient;
    _sbAwaitingXfr = false;
    _sbXfrTimeout?.cancel();
    _sbXfrTimeout = null;
    unawaited(
      _connectSwitchboard(
        host: hostParts[0],
        port: port,
        authToken: authToken,
        inviteMode: false,
        sessionId: '',
        contactEmail: recipient,
      ),
    );
  }

  void _onSbDone() {
    _log('Switchboard socket closed by remote endpoint.');
    _cancelSbJoinTimeout();
    _handledAvatarSessionIds.clear();
    final closedEmail = _sbContactEmail;
    _sbSocket = null;
    _sbPendingFrame = null;
    _sbRxBuffer.clear();
    _sbReady = false;
    _sbConnecting = false;
    _sbIsSilentAvatarSession = false;
    _sbIsInviteMode = false;

    // Immediately fail any active incoming file transfers on this SB.
    if (closedEmail != null) {
      _fileTransferService.failActiveSessionsForPeer(closedEmail);
    }

    // If the SB that just closed was carrying a P2P transfer, re-queue it
    // for retry (up to 2 times) instead of permanently failing.
    if (closedEmail != null && _sbP2pInFlightEmail == closedEmail) {
      // Close any active P2P sessions for this peer so the "Downloading..."
      // status is cleared from the UI.
      _p2pSessionManager.closeAllSessionsForPeer(closedEmail);
      _clearP2pInFlight(closedEmail);

      final retries = _avatarSbRetryCount[closedEmail] ?? 0;
      if (retries < 2) {
        _avatarSbRetryCount[closedEmail] = retries + 1;
        _log(
          'SB closed while P2P in-flight for $closedEmail — '
          're-queuing (retry ${retries + 1}/2).',
        );
        _avatarInvitePending.add(closedEmail);
        _avatarInviteSent.removeWhere((k) => k.startsWith('$closedEmail|'));
        _avatarSilentRequested.removeWhere(
          (k) => k.startsWith('$closedEmail|'),
        );
        _tryNextPendingAvatar();
      } else {
        _log(
          'SB closed while P2P in-flight for $closedEmail — '
          'max retries reached, marking as failed.',
        );
        _markAvatarFetchFailed(
          closedEmail,
          reason:
              'SB closed before transfer completed (after $retries retries)',
        );
      }
      return;
    }
    if (_socket != null && _sbOutboundQueue.isNotEmpty) {
      _ensureOutboundSwitchboard(_sbOutboundQueue.first.to);
    }
    _tryNextPendingAvatar();
  }

  void _onSbError(Object error, StackTrace stackTrace) {
    _log('Switchboard socket error: $error');
    _cancelSbJoinTimeout();
    _handledAvatarSessionIds.clear();
    final closedEmail = _sbContactEmail;
    _sbSocket = null;
    _sbPendingFrame = null;
    _sbRxBuffer.clear();
    _sbReady = false;
    _sbConnecting = false;
    _sbIsSilentAvatarSession = false;
    _sbIsInviteMode = false;

    // Immediately fail any active incoming file transfers on this SB.
    if (closedEmail != null) {
      _fileTransferService.failActiveSessionsForPeer(closedEmail);
    }

    // Release the P2P in-flight lock so the pipeline doesn't deadlock.
    if (closedEmail != null && _sbP2pInFlightEmail == closedEmail) {
      _clearP2pInFlight(closedEmail);

      final retries = _avatarSbRetryCount[closedEmail] ?? 0;
      if (retries < 2) {
        _avatarSbRetryCount[closedEmail] = retries + 1;
        _log(
          'SB error while P2P in-flight for $closedEmail — '
          're-queuing (retry ${retries + 1}/2).',
        );
        _avatarInvitePending.add(closedEmail);
        _avatarInviteSent.removeWhere((k) => k.startsWith('$closedEmail|'));
        _avatarSilentRequested.removeWhere(
          (k) => k.startsWith('$closedEmail|'),
        );
        _tryNextPendingAvatar();
      } else {
        _log(
          'SB error while P2P in-flight for $closedEmail — '
          'max retries reached.',
        );
        _markAvatarFetchFailed(
          closedEmail,
          reason: 'SB socket error (after $retries retries)',
        );
      }
      return;
    }
    _tryNextPendingAvatar();
  }

  void _startSbJoinTimeout(String contactEmail) {
    _cancelSbJoinTimeout();
    _sbJoinTimeoutContact = contactEmail.trim().toLowerCase();
    _sbJoinTimeoutTimer = Timer(const Duration(seconds: 6), _onSbJoinTimeout);
  }

  void _cancelSbJoinTimeout() {
    _sbJoinTimeoutTimer?.cancel();
    _sbJoinTimeoutTimer = null;
    _sbJoinTimeoutContact = null;
  }

  void _onSbJoinTimeout() {
    final failedContact = _sbJoinTimeoutContact;
    _cancelSbJoinTimeout();
    if (failedContact == null || failedContact.isEmpty) {
      return;
    }

    _markAvatarFetchFailed(
      failedContact,
      reason: 'Silent switchboard JOI timeout (no JOI after CAL in 10s)',
      closeSwitchboard: true,
    );
  }

  void _markAvatarFetchFailed(
    String contactEmail, {
    required String reason,
    bool closeSwitchboard = false,
  }) {
    final failedContact = contactEmail.trim().toLowerCase();
    if (failedContact.isEmpty) {
      return;
    }

    _log('Avatar fetch failed for $failedContact: $reason');
    if (closeSwitchboard) {
      _sbSocket?.destroy();
      _sbSocket = null;
      _sbReady = false;
      _sbConnecting = false;
      _sbAwaitingXfr = false;
      _sbIsInviteMode = false;
      _sbAuthToken = null;
      _sbHost = null;
      _sbPort = null;
      _sbSessionId = null;
      _sbContactEmail = null;
      _sbPendingRecipient = null;
      _sbPendingFrame = null;
      _sbRxBuffer.clear();
    }

    _avatarInvitePending.remove(failedContact);
    _avatarBackgroundFailed.add(failedContact);
    _avatarSilentRequested.removeWhere(
      (key) => key.startsWith('$failedContact|'),
    );
    _avatarInviteSent.removeWhere((key) => key.startsWith('$failedContact|'));

    _sbOutboundQueue.removeWhere((item) {
      final isAvatarP2p = item.msgFlag.toUpperCase() == 'D';
      return item.to == failedContact && isAvatarP2p;
    });

    _eventController.add(
      MsnpEvent(
        type: MsnpEventType.system,
        command: 'AVFAIL',
        from: failedContact,
        raw: 'AVFAIL $failedContact',
      ),
    );
    // Release the in-flight lock and kick off the next pending transfer.
    _clearP2pInFlight(failedContact);
    _tryNextPendingAvatar();
  }

  /// Releases the P2P in-flight lock for [email] and cancels any pending timer.
  void _clearP2pInFlight(String email) {
    if (_sbP2pInFlightEmail == email) {
      _sbP2pResponseTimeout?.cancel();
      _sbP2pResponseTimeout = null;
      _sbP2pInFlightEmail = null;
      _avatarStallTimers[email]?.cancel();
      _avatarStallTimers.remove(email);
      _log('P2P in-flight lock released for $email');
    }
  }

  /// After a transfer completes or fails, start the next avatar fetch from
  /// any remaining contacts still in [_avatarInvitePending].
  void _tryNextPendingAvatar() {
    if (_sbP2pInFlightEmail != null) return; // still busy
    final pending = _avatarInvitePending.toList();
    for (final email in pending) {
      if (_avatarBackgroundFailed.contains(email)) continue;
      final known = _knownContacts[email];
      if (known == null) {
        _avatarInvitePending.remove(email);
        continue;
      }
      final sha = (known.avatarSha1d ?? '').trim();
      final msnObj = (known.avatarMsnObject ?? '').trim();
      if (sha.isEmpty || msnObj.isEmpty) {
        _avatarInvitePending.remove(email);
        continue;
      }
      // Clear the per-contact SB-requested dedup so the XFR can be issued.
      _avatarSilentRequested.removeWhere((k) => k.startsWith('$email|'));
      _log('_tryNextPendingAvatar → starting avatar fetch for $email');
      _queueAvatarInvite(
        contactEmail: email,
        avatarSha1d: sha,
        fullMsnObjectXml: msnObj,
        eagerBackground: true,
      );
      return; // process one at a time — the next will be triggered on completion
    }

    // Avatar queue drained — process any RNG invitations that were deferred.
    _drainDeferredRng();
  }

  /// Replays deferred RNG lines now that the avatar pipeline is idle.
  void _drainDeferredRng() {
    if (_deferredRngLines.isEmpty) return;
    // Take the most recent RNG only — older sessions may have expired.
    final line = _deferredRngLines.removeLast();
    _deferredRngLines.clear();
    _log('Replaying deferred RNG after avatar pipeline idle.');
    _handleRng(line);
  }

  /// Called by [_p2pSessionManager] when a display picture is fully reassembled.
  void _onP2pAvatarReady(String peerEmail, String filePath, {String? sha1d}) {
    final normalized = peerEmail.trim().toLowerCase();
    _log('P2P avatar ready for $normalized → $filePath');
    // Release the in-flight lock so the next queued contact can start.
    _clearP2pInFlight(normalized);
    // Clear the failed/in-flight flags so the new path is picked up.
    _avatarBackgroundFailed.remove(normalized);
    _avatarSbRetryCount.remove(normalized);
    // Keep _avatarInviteSent so the same sha1d is NOT re-fetched.
    // Also remove this contact from the pending queue to prevent re-INVITE.
    _avatarInvitePending.remove(normalized);
    final sha = sha1d ?? '';
    _eventController.add(
      MsnpEvent(
        type: MsnpEventType.system,
        command: 'AVOK',
        from: normalized,
        body: '$filePath\n$sha',
        raw: 'AVOK $normalized $filePath $sha',
      ),
    );
    // Tear down the old SB immediately so the next XFR can start without
    // waiting for the peer to close the connection.
    unawaited(_disconnectSwitchboard());
    // Start the next pending avatar transfer for OTHER contacts.
    _tryNextPendingAvatar();
  }

  void _onData(List<int> data) {
    _rxBuffer.addAll(data);

    while (true) {
      if (_pendingFrame != null) {
        final pending = _pendingFrame!;
        if (_rxBuffer.length < pending.length) {
          return;
        }

        final payloadBytes = _rxBuffer.sublist(0, pending.length);
        _rxBuffer.removeRange(0, pending.length);
        final payload = utf8.decode(payloadBytes, allowMalformed: true);

        _handlePayload(pending, payload);
        _pendingFrame = null;

        // CrossTalk sometimes emits an extra separator after payload frames.
        _trimLeadingCrlf();
        continue;
      }

      final splitIndex = _indexOfCrlf(_rxBuffer);
      if (splitIndex == -1) {
        return;
      }

      final lineBytes = _rxBuffer.sublist(0, splitIndex);
      _rxBuffer.removeRange(0, splitIndex + 2);
      final line = utf8.decode(lineBytes, allowMalformed: true);
      if (line.isEmpty) {
        continue;
      }

      _logRx(line);

      final pendingLength = _extractPayloadLength(line);
      if (pendingLength != null) {
        _handleLine(line);
        _pendingFrame = _PendingFrame.fromHeader(
          headerLine: line,
          length: pendingLength,
          defaultTo: _email,
        );
        continue;
      }

      _handleLine(line);
    }
  }

  void _handleLine(String line) {
    final event = MsnpParser.parseLine(line);
    _rememberFromRawLine(line, event);
    _rememberFromEvent(event);
    _eventController.add(event);

    switch (event.command) {
      case 'VER':
        _log('Handshake step: VER received, sending CVR');
        _send(MsnpCommands.cvr(_nextTrId(), _email));
        break;
      case 'CVR':
        _log('Handshake step: CVR received, sending USR TWN I');
        _send(MsnpCommands.usrTwnI(_nextTrId(), _email));
        break;
      case 'USR':
        if (line.contains('TWN S')) {
          _log('Handshake step: USR TWN S challenge received, sending ticket');
          final encodedTicket = Uri.encodeComponent(_ticket);
          _send(MsnpCommands.usrTwnS(_nextTrId(), encodedTicket));
        } else if (line.contains(' OK ')) {
          _log('Handshake step: USR OK received, sending CHG/BLP bootstrap');
          _synRejected = false;
          _synAttemptStage = 0;
          _log(
            'SYN disabled for this session; waiting for server-driven contact updates.',
          );
          _sendPostAuthBootstrap();
          _startAbchRosterFetch();
          _statusController.add(ConnectionStatus.connected);
          _startKeepAlive();
          _log('MSNP connection authenticated and ready.');
        }
        break;
      case 'CHL':
        _respondToChallenge(line);
        break;
      case 'QRY':
        _handleChallengeAccepted(line);
        break;
      case 'CHG':
        _statusController.add(ConnectionStatus.connected);
        _startKeepAlive();
        break;
      case '502':
        _handleCommandRejected(line);
        break;
      case 'QNG':
        _updateKeepAliveIntervalFromQng(line);
        _log('Keep-alive acknowledged (QNG).');
        break;
      case '540':
        _log('Server timeout warning received: $line');
        if (_retryChallengeProfileOnTimeout(line)) {
          break;
        }
        if (_socket != null) {
          _send(MsnpCommands.png());
        }
        break;
      case 'RNG':
        _handleRng(line);
        break;
      case 'XFR':
        _handleXfr(line);
        break;
      default:
        break;
    }
  }

  void _handlePayload(_PendingFrame frame, String payload) {
    if (frame.command == 'MSG') {
      if ((frame.from ?? '').toLowerCase() == 'hotmail') {
        final compact = payload
            .replaceAll('\r', ' ')
            .replaceAll('\n', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        _sbIsInviteMode = false;
        const chunkSize = 420;
        if (compact.length <= chunkSize) {
          _log('Hotmail payload preview: $compact');
        } else {
          final chunks = (compact.length / chunkSize).ceil();
          for (var i = 0; i < chunks && i < 4; i += 1) {
            final start = i * chunkSize;
            final end = (start + chunkSize) > compact.length
                ? compact.length
                : (start + chunkSize);
            _log(
              'Hotmail payload preview [${i + 1}/$chunks]: ${compact.substring(start, end)}',
            );
          }
        }
      }

      // Do not synthesize contacts from generic Hotmail/system payloads.
      // Contact list must come from explicit roster/presence protocol sources.

      final payloadEvent = MsnpParser.parseMsgPayload(
        from: frame.from ?? 'unknown',
        to: frame.to ?? _email,
        payload: payload,
      );
      if ((frame.from ?? '').toLowerCase() == 'hotmail' &&
          payload.contains('Content-Type: text/x-msmsgsprofile')) {
        _captureProfileTokens(payload);
      }
      _eventController.add(payloadEvent);
      return;
    }

    if (frame.command == 'GCF') {
      _log('GCF payload received (${frame.length} bytes).');
      return;
    }

    if (frame.command == 'UBX') {
      final rawPsm = _extractXmlTag(payload, 'PSM');
      final currentMedia = _extractXmlTag(payload, 'CurrentMedia');
      final scene = _extractXmlTagAllowEmpty(payload, 'Scene');
      final colorScheme = _extractXmlTagAllowEmpty(payload, 'ColorScheme');
      final rawDdp = _extractXmlTagAllowEmpty(payload, 'DDP');
      final from = frame.from?.toLowerCase();
      if (from != null && from.isNotEmpty) {
        String? psm;
        if (rawPsm != null && rawPsm.isNotEmpty) {
          try {
            psm = Uri.decodeComponent(rawPsm.replaceAll('+', ' '));
          } catch (_) {
            psm = rawPsm;
          }
        }
        final media = _parseCurrentMedia(currentMedia);

        // Parse DDP (Dynamic Display Picture) MSN Object if present.
        String? ddpMsnObject;
        String? ddpSha1d;
        if (rawDdp != null && rawDdp.isNotEmpty) {
          // UBX encodes XML entities: &#x3C; = <, &#x3D; = =, &#x3E; = >, etc.
          ddpMsnObject = rawDdp
              .replaceAll('&#x3C;', '<')
              .replaceAll('&#x3E;', '>')
              .replaceAll('&#x3D;', '=')
              .replaceAll('&#x22;', '"')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&amp;', '&')
              .replaceAll('&quot;', '"');
          ddpSha1d = _extractMsnObjectAttr(ddpMsnObject, 'SHA1D');
          if (ddpSha1d != null && ddpSha1d.isNotEmpty) {
            _log('[DDP] UBX from $from has DDP sha1d=$ddpSha1d');
          } else {
            ddpMsnObject = null;
            ddpSha1d = null;
          }
        }

        // Directly update the snapshot entry so that null values *clear*
        // stale personalMessage / nowPlaying instead of being preserved by
        // copyWith's null-fallback behaviour.
        // For scene/colorScheme: the tag being present but empty means "default" —
        // we store empty string to clear a previously cached value.
        // The tag being absent means "no change" (not included in this UBX).
        final existing = _knownContacts[from];
        if (existing != null) {
          _knownContacts[from] = _KnownContact(
            email: existing.email,
            displayName: existing.displayName,
            status: existing.status,
            personalMessage: psm,
            nowPlaying: media,
            avatarMsnObject: existing.avatarMsnObject,
            avatarCreator: existing.avatarCreator,
            avatarSha1d: existing.avatarSha1d,
            ddpMsnObject: ddpMsnObject ?? existing.ddpMsnObject,
            ddpSha1d: ddpSha1d ?? existing.ddpSha1d,
            scene: scene ?? existing.scene,
            colorScheme: colorScheme ?? existing.colorScheme,
          );
        } else {
          _rememberContact(
            email: from,
            personalMessage: psm,
            nowPlaying: media,
            scene: scene,
            colorScheme: colorScheme,
          );
        }

        // DDP (Dynamic Display Picture) fetching is disabled — the P2P
        // session for animated GIF avatars is unstable and often causes
        // "Invalid image data" errors.
        // if (ddpSha1d != null && ddpSha1d.isNotEmpty && ddpMsnObject != null) {
        //   _queueAvatarInvite(
        //     contactEmail: from,
        //     avatarSha1d: ddpSha1d,
        //     fullMsnObjectXml: ddpMsnObject,
        //     eagerBackground: true,
        //   );
        // }

        if (scene != null || colorScheme != null) {
          print(
            '[MSNP] UBX from $from: scene=${scene ?? "(absent)"}, '
            'colorScheme=${colorScheme ?? "(absent)"}',
          );
        }
        _eventController.add(
          MsnpEvent(
            type: MsnpEventType.system,
            command: 'UBX',
            from: from,
            body: psm,
            raw: 'UBX $from',
          ),
        );
      }

      _log('UBX payload received (${frame.length} bytes): $payload');
    }
  }

  void _respondToChallenge(String line) {
    final parts = line.trim().split(' ');
    if (parts.length < 3) {
      _log('Received malformed CHL command: $line');
      return;
    }

    _lastChallenge = parts[2];
    _synRetriedAfterChallenge = false;
    _challengeRetryCount = 0;
    _sendChallengeResponse();
  }

  void _handleChallengeAccepted(String line) {
    final parts = line.trim().split(' ');
    if (parts.length < 2) {
      return;
    }

    final trId = int.tryParse(parts[1]);
    if (trId == null || _lastQryTrId == null || trId != _lastQryTrId) {
      return;
    }

    _challengeAcked = true;
    _challengeAckTimer?.cancel();
    _challengeAckTimer = null;
    _challengeRetryCount = 0;

    if (!_synRejected || _synRetriedAfterChallenge) {
      return;
    }

    _log('Challenge accepted; SYN remains disabled by design in MSNP15 flow.');
  }

  void _sendChallengeResponse() {
    if (_lastChallenge == null) {
      return;
    }

    final profile = _challengeProfiles[_challengeProfileIndex];
    final cleanChallenge = _lastChallenge!.trim();
    var response = _computeChallengeResponse(
      challenge: cleanChallenge,
      productId: profile.qryTarget,
      productKey: profile.productKey,
      mode: profile.mode,
    );
    _log('Computed QRY hash for challenge $cleanChallenge: $response');
    final qrtTrId = _nextTrId();
    _lastQryTrId = qrtTrId;
    _activeChallengeTrId = qrtTrId;
    _challengeAcked = false;

    final qryPayload = response;
    final headerString =
        'QRY $qrtTrId ${profile.qryTarget} ${qryPayload.length}';
    final headerBytes = ascii.encode(headerString);
    final crlfBytes = <int>[13, 10];
    final payloadBytes = ascii.encode(qryPayload);

    // Must be one contiguous write with explicit CRLF and no trailing CRLF after payload.
    final rawBytes = <int>[...headerBytes, ...crlfBytes, ...payloadBytes];
    _logTx('$headerString\r\n$qryPayload');
    _socket?.add(rawBytes);
    _log(
      'Challenge response sent (QRY) using profile ${_challengeProfileIndex + 1}/${_challengeProfiles.length}.',
    );

    _challengeAckTimer?.cancel();
    _challengeAckTimer = Timer(
      const Duration(seconds: 4),
      _onChallengeAckTimeout,
    );
  }

  void _onChallengeAckTimeout() {
    if (_challengeAcked || _socket == null || _activeChallengeTrId == null) {
      return;
    }

    if (_challengeRetryCount >= _challengeProfiles.length - 1) {
      _log(
        'No QRY acknowledgement for transaction $_activeChallengeTrId after profile retries.',
      );
      return;
    }

    _challengeRetryCount += 1;
    _challengeProfileIndex =
        (_challengeProfileIndex + 1) % _challengeProfiles.length;
    _log(
      'No QRY acknowledgement for transaction $_activeChallengeTrId; retrying challenge '
      'with profile ${_challengeProfileIndex + 1}/${_challengeProfiles.length}.',
    );
    _sendChallengeResponse();
  }

  String _computeChallengeResponse({
    required String challenge,
    required String productId,
    required String productKey,
    required _ChallengeMode mode,
  }) {
    if (mode == _ChallengeMode.msnp11) {
      return _computeMsnp11ChallengeResponse(
        challenge: challenge,
        productId: productId,
        productKey: productKey,
      );
    }

    final input = '$challenge$productKey';
    return md5.convert(utf8.encode(input)).toString();
  }

  String _computeMsnp11ChallengeResponse({
    required String challenge,
    required String productId,
    required String productKey,
  }) {
    final digest = md5.convert(utf8.encode('$challenge$productKey')).bytes;

    int readLe32(List<int> bytes, int offset) {
      return bytes[offset] |
          (bytes[offset + 1] << 8) |
          (bytes[offset + 2] << 16) |
          (bytes[offset + 3] << 24);
    }

    final md5Ints = <int>[
      readLe32(digest, 0) & 0x7fffffff,
      readLe32(digest, 4) & 0x7fffffff,
      readLe32(digest, 8) & 0x7fffffff,
      readLe32(digest, 12) & 0x7fffffff,
    ];

    final challengeBytes = utf8.encode('$challenge$productId');
    final paddedLength = ((challengeBytes.length + 7) ~/ 8) * 8;
    final padded = List<int>.filled(paddedLength, 0x30);
    for (var i = 0; i < challengeBytes.length; i += 1) {
      padded[i] = challengeBytes[i];
    }

    final chlInts = <int>[];
    for (var i = 0; i < padded.length; i += 4) {
      chlInts.add(readLe32(padded, i));
    }

    var high = 0;
    var low = 0;
    const modulo = 0x7fffffff;

    for (var i = 0; i < chlInts.length - 1; i += 2) {
      final temp = (md5Ints[0] * chlInts[i] + md5Ints[1]) % modulo;
      high = (md5Ints[2] * temp + md5Ints[3]) % modulo;
      low = (low + high + temp) % modulo;
    }

    high = (high + md5Ints[1]) % modulo;
    low = (low + md5Ints[3]) % modulo;

    final keyInts = <int>[
      (readLe32(digest, 0) ^ high) & 0xffffffff,
      (readLe32(digest, 4) ^ low) & 0xffffffff,
      (readLe32(digest, 8) ^ high) & 0xffffffff,
      (readLe32(digest, 12) ^ low) & 0xffffffff,
    ];

    final out = <int>[];
    for (final value in keyInts) {
      out.add(value & 0xff);
      out.add((value >> 8) & 0xff);
      out.add((value >> 16) & 0xff);
      out.add((value >> 24) & 0xff);
    }

    final buffer = StringBuffer();
    for (final byte in out) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  void _handleCommandRejected(String line) {
    final parts = line.trim().split(' ');
    if (parts.length < 2) {
      return;
    }

    final trId = int.tryParse(parts[1]);
    if (trId == null || _lastSynTrId == null) {
      return;
    }

    if (trId == _lastSynTrId) {
      _serverSupportsSyn = false;
      _knownServerSynUnsupported = true;
      _synRejected = true;
      _log(
        'Server rejected SYN transaction $trId (502). Disabling SYN and waiting for server-driven contact updates.',
      );
    }
  }

  void _sendContactSyncRequest() {
    _log('Ignoring contact sync request because SYN is disabled.');
  }

  void _sendPostAuthBootstrap() {
    if (_sentPostAuthBootstrap) {
      return;
    }
    _sentPostAuthBootstrap = true;

    final chgCmd = MsnpCommands.chg(
      _nextTrId(),
      presenceToMsnp(_selfPresence),
      capabilities: MsnpCommands.wlm2009Capabilities,
      msnObject: _encodedSelfMsnObject,
    );
    _log('CHG command: ${chgCmd.trim()}');
    _log(
      '_encodedSelfMsnObject is ${_encodedSelfMsnObject == null ? "NULL" : "${_encodedSelfMsnObject!.length} chars"}',
    );
    _send(chgCmd);
    _send(MsnpCommands.blp(_nextTrId(), 'AL'));
    _send(MsnpCommands.adlEmpty(_nextTrId()));
    _sendUux();
    _log(
      'Post-auth bootstrap commands sent (CHG/BLP/UUX) with avatar=${_selfAvatarMsnObject != null ? "set" : "none"}.',
    );
  }

  void _retryContactSyncRequest() {
    if (_synAttemptStage >= 3) {
      if (!_sentLegacySyncBootstrap) {
        _sentLegacySyncBootstrap = true;
        _log(
          'SYN retries exhausted; sending legacy BLP fallback and retrying SYN.',
        );
        _send(MsnpCommands.blp(_nextTrId(), 'AL'));
        _synAttemptStage = 0;
        _sendContactSyncRequest();
        return;
      }

      _log(
        'Contact sync retries exhausted after SYN rejection; waiting for server-driven list updates.',
      );
      return;
    }

    _synAttemptStage += 1;
    _sendContactSyncRequest();
  }

  bool _retryChallengeProfileOnTimeout(String line) {
    final parts = line.trim().split(' ');
    if (parts.length < 2) {
      return false;
    }

    final trId = int.tryParse(parts[1]);
    if (trId == null || _lastQryTrId == null || trId != _lastQryTrId) {
      return false;
    }

    _challengeProfileIndex =
        (_challengeProfileIndex + 1) % _challengeProfiles.length;
    _log(
      'QRY transaction $trId timed out; switching to challenge profile '
      '${_challengeProfileIndex + 1}/${_challengeProfiles.length} for the next connection attempt.',
    );
    return false;
  }

  int _indexOfCrlf(List<int> bytes) {
    for (var i = 0; i < bytes.length - 1; i += 1) {
      if (bytes[i] == 13 && bytes[i + 1] == 10) {
        return i;
      }
    }
    return -1;
  }

  int? _extractPayloadLength(String line) {
    final parts = line.trim().split(' ');
    if (parts.length < 2) {
      return null;
    }

    final command = parts.first.toUpperCase();
    const payloadCommands = <String>{'MSG', 'GCF', 'UBX'};
    if (!payloadCommands.contains(command)) {
      return null;
    }

    final payloadLength = int.tryParse(parts.last);
    if (payloadLength == null || payloadLength <= 0) {
      return null;
    }

    return payloadLength;
  }

  void _trimLeadingCrlf() {
    while (_rxBuffer.length >= 2 && _rxBuffer[0] == 13 && _rxBuffer[1] == 10) {
      _rxBuffer.removeRange(0, 2);
    }
  }

  void _onDone() {
    _stopKeepAlive();
    _socket = null;
    unawaited(_disconnectSwitchboard());
    _sbOutboundQueue.clear();
    _sbAwaitingXfr = false;
    _sbPendingRecipient = null;
    _sbP2pResponseTimeout?.cancel();
    _sbP2pResponseTimeout = null;
    _sbP2pInFlightEmail = null;
    if (_activeChallengeTrId != null && !_challengeAcked) {
      _challengeProfileIndex =
          (_challengeProfileIndex + 1) % _challengeProfiles.length;
      _log(
        'Remote closed before QRY ack for transaction $_activeChallengeTrId; '
        'switching challenge profile to ${_challengeProfileIndex + 1}/${_challengeProfiles.length} for next connect.',
      );
    }

    _challengeAckTimer?.cancel();
    _challengeAckTimer = null;
    _activeChallengeTrId = null;
    _challengeAcked = false;
    _challengeRetryCount = 0;
    _log('Socket closed by remote endpoint.');
    _statusController.add(ConnectionStatus.disconnected);
  }

  void _onError(Object error, StackTrace stackTrace) {
    _stopKeepAlive();
    _socket = null;
    unawaited(_disconnectSwitchboard());
    _sbOutboundQueue.clear();
    _sbAwaitingXfr = false;
    _sbP2pResponseTimeout?.cancel();
    _sbP2pResponseTimeout = null;
    _sbP2pInFlightEmail = null;
    _sbPendingRecipient = null;
    _challengeAckTimer?.cancel();
    _challengeAckTimer = null;
    _log('Socket error: $error');
    _statusController.add(ConnectionStatus.error);
  }

  void _startKeepAlive() {
    _stopKeepAlive();
    _keepAliveTimer = Timer.periodic(Duration(seconds: _keepAliveSeconds), (_) {
      if (_socket == null) {
        return;
      }
      _send(MsnpCommands.png());
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  /// Periodically checks if outbound text messages are stuck in the SB queue.
  /// If messages have been waiting > 10 seconds while P2P is in-flight, force
  /// a new SB session by temporarily clearing the P2P guard.
  void _startSbQueueWatchdog() {
    _sbQueueWatchdog?.cancel();
    _sbQueueWatchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sbOutboundQueue.isEmpty || _socket == null) return;
      // Only check text messages (not P2P data frames which have msgFlag 'D')
      final hasStuckText = _sbOutboundQueue.any(
        (m) => m.fallbackToNotificationServer && m.msgFlag != 'D',
      );
      if (!hasStuckText) return;
      // If not currently connecting/awaiting XFR, kick a new SB request
      if (!_sbConnecting && !_sbAwaitingXfr) {
        final firstText = _sbOutboundQueue.firstWhere(
          (m) => m.fallbackToNotificationServer && m.msgFlag != 'D',
        );
        _ensureOutboundSwitchboard(firstText.to, bypassP2pLock: true);
      }
    });
  }

  void _stopSbQueueWatchdog() {
    _sbQueueWatchdog?.cancel();
    _sbQueueWatchdog = null;
  }

  void _updateKeepAliveIntervalFromQng(String line) {
    final parts = line.split(' ');
    if (parts.length < 2) {
      return;
    }

    final serverSeconds = int.tryParse(parts[1]);
    if (serverSeconds == null || serverSeconds <= 0) {
      return;
    }

    final nextSeconds = (serverSeconds - 10).clamp(15, 55);
    if (nextSeconds == _keepAliveSeconds) {
      return;
    }

    _keepAliveSeconds = nextSeconds;
    if (_socket != null) {
      _startKeepAlive();
    }
  }

  Future<String> _resolveTicket({
    required String host,
    required String email,
    required String password,
    required String fallbackTicket,
  }) async {
    final soapTicket = await _requestSoapTicket(
      host: host,
      email: email,
      password: password,
    );

    if (soapTicket != null && soapTicket.isNotEmpty) {
      _log(
        'Using SOAP authentication token from port ${ServerConfig.authPort}.',
      );
      return soapTicket;
    }

    if (fallbackTicket.isNotEmpty) {
      _log('SOAP token unavailable; falling back to provided ticket.');
      return fallbackTicket;
    }

    _log('SOAP token unavailable; falling back to password as ticket.');
    return password;
  }

  Future<String?> _requestSoapTicket({
    required String host,
    required String email,
    required String password,
  }) async {
    final uri = ServerConfig.authUri(hostOverride: host);
    final client = HttpClient()..connectionTimeout = ServerConfig.authTimeout;

    try {
      _log('Attempting SOAP auth request: POST $uri');
      final request = await client
          .postUrl(uri)
          .timeout(ServerConfig.authTimeout);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'text/xml; charset=utf-8',
      );
      request.headers.set(
        'SOAPAction',
        'http://schemas.xmlsoap.org/ws/2005/02/trust/RST/Issue',
      );

      final soapBody = _buildSoapEnvelope(email: email, password: password);
      request.add(utf8.encode(soapBody));

      final response = await request.close().timeout(ServerConfig.authTimeout);
      final responseBody = await response.transform(utf8.decoder).join();
      _log('SOAP response status: ${response.statusCode}');
      print('RAW SOAP: $responseBody');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _log('SOAP auth endpoint returned non-success status.');
        return null;
      }

      final token = _extractSoapToken(responseBody);
      if (token == null) {
        _log('SOAP response received but no token pattern matched.');
        return null;
      }

      _log('SOAP token extracted successfully.');
      return token;
    } on SocketException catch (error) {
      _log('SOAP auth socket error: $error');
      return null;
    } on TimeoutException {
      _log('SOAP auth request timed out.');
      return null;
    } catch (error) {
      _log('SOAP auth request failed: $error');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  String _buildSoapEnvelope({required String email, required String password}) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"
    xmlns:wsp="http://schemas.xmlsoap.org/ws/2004/09/policy"
  xmlns:wsa="http://www.w3.org/2005/08/addressing"
    xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
    xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
    xmlns:wst="http://schemas.xmlsoap.org/ws/2005/02/trust"
    xmlns:ps="http://schemas.microsoft.com/Passport/SoapServices/PPCRL">
  <s:Header>
    <wsse:Security>
      <wsse:UsernameToken wsu:Id="user">
        <wsse:Username>$email</wsse:Username>
        <wsse:Password>$password</wsse:Password>
      </wsse:UsernameToken>
    </wsse:Security>
  </s:Header>
  <s:Body>
    <wst:RequestSecurityToken>
      <wst:RequestType>http://schemas.xmlsoap.org/ws/2005/02/trust/Issue</wst:RequestType>
      <wsp:AppliesTo>
        <wsa:EndpointReference>
          <wsa:Address>messenger.msn.com</wsa:Address>
        </wsa:EndpointReference>
      </wsp:AppliesTo>
    </wst:RequestSecurityToken>
  </s:Body>
</s:Envelope>
''';
  }

  String? _extractSoapToken(String responseBody) {
    final tokenRegex = RegExp(
      r'<wsse:BinarySecurityToken[^>]*>(.*?)</wsse:BinarySecurityToken>',
      dotAll: true,
    );
    final match = tokenRegex.firstMatch(responseBody);
    if (match == null) {
      return null;
    }

    return _normalizeXmlText(match.group(1) ?? '');
  }

  String _normalizeXmlText(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .trim();
  }

  void _log(String message) {
    print('[MSNP] $message');
  }

  void _logTx(String command) {
    final line = command.replaceAll('\r', r'\r').replaceAll('\n', r'\n');
    print('[MSNP][TX] $line');
  }

  void _logRx(String line) {
    if (line.isEmpty) {
      return;
    }
    print('[MSNP][RX] $line');
  }

  void _rememberFromEvent(MsnpEvent event) {
    if (event.from == null) {
      return;
    }

    if (event.type == MsnpEventType.presence) {
      if (event.command.toUpperCase() == 'FLN') {
        _rememberContact(
          email: event.from!,
          status: PresenceStatus.appearOffline,
        );
        return;
      }
      _rememberContact(
        email: event.from!,
        displayName: (event.body == null || event.body!.isEmpty)
            ? event.from!
            : event.body!,
        status: event.presence ?? PresenceStatus.online,
      );
      return;
    }

    if (event.type == MsnpEventType.contact) {
      _rememberContact(
        email: event.from!,
        displayName: (event.body == null || event.body!.isEmpty)
            ? event.from!
            : event.body!,
        status: PresenceStatus.appearOffline,
      );
    }
  }

  void _rememberContact({
    required String email,
    String? displayName,
    PresenceStatus? status,
    String? personalMessage,
    String? nowPlaying,
    String? avatarMsnObject,
    String? avatarCreator,
    String? avatarSha1d,
    String? scene,
    String? colorScheme,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || normalizedEmail == _email.toLowerCase()) {
      return;
    }

    final existing = _knownContacts[normalizedEmail];
    if (existing == null) {
      _knownContacts[normalizedEmail] = _KnownContact(
        email: normalizedEmail,
        displayName: (displayName == null || displayName.trim().isEmpty)
            ? normalizedEmail
            : displayName,
        status: status ?? PresenceStatus.appearOffline,
        personalMessage: personalMessage,
        nowPlaying: nowPlaying,
        avatarMsnObject: avatarMsnObject,
        avatarCreator: avatarCreator,
        avatarSha1d: avatarSha1d,
        scene: scene,
        colorScheme: colorScheme,
      );
      return;
    }

    _knownContacts[normalizedEmail] = existing.copyWith(
      displayName: _mergeDisplayName(
        existingDisplayName: existing.displayName,
        incomingDisplayName: displayName,
        email: normalizedEmail,
      ),
      status: status ?? existing.status,
      personalMessage: personalMessage,
      nowPlaying: nowPlaying,
      avatarMsnObject: avatarMsnObject,
      avatarCreator: avatarCreator,
      avatarSha1d: avatarSha1d,
      scene: scene ?? existing.scene,
      colorScheme: colorScheme ?? existing.colorScheme,
    );
  }

  String _mergeDisplayName({
    required String existingDisplayName,
    required String? incomingDisplayName,
    required String email,
  }) {
    if (incomingDisplayName == null || incomingDisplayName.trim().isEmpty) {
      return existingDisplayName;
    }

    final next = incomingDisplayName.trim();
    final existing = existingDisplayName.trim();
    final emailLower = email.toLowerCase();
    final emailLocalPart = email.split('@').first.toLowerCase();
    if (existing.isEmpty ||
        existing.toLowerCase() == emailLower ||
        existing.toLowerCase() == emailLocalPart) {
      return next;
    }

    if (next.toLowerCase() == emailLower ||
        next.toLowerCase() == emailLocalPart) {
      return existing;
    }

    if (RegExp(r'^[0-9]{1,3}$').hasMatch(next)) {
      return existing;
    }

    return next;
  }

  void _rememberFromRawLine(String line, MsnpEvent event) {
    final command = event.command.toUpperCase();
    if (command != 'ILN' && command != 'NLN') {
      return;
    }

    var lineWithoutObj = line.trim();
    String? msnObject;
    final objIndex = lineWithoutObj.indexOf('%3Cmsnobj');
    if (objIndex != -1) {
      final encodedObj = lineWithoutObj.substring(objIndex).trim();
      msnObject = Uri.decodeComponent(encodedObj);
      lineWithoutObj = lineWithoutObj.substring(0, objIndex).trimRight();
    }

    final parts = lineWithoutObj.split(' ');
    final email = event.from;
    if (email == null || email.isEmpty) {
      return;
    }

    String? nick;
    if (command == 'ILN' && parts.length >= 6) {
      nick = Uri.decodeComponent(parts[5].replaceAll('+', ' ')).trim();
    }
    if (command == 'NLN' && parts.length >= 5) {
      nick = Uri.decodeComponent(parts[4].replaceAll('+', ' ')).trim();
    }
    if (nick == '1' || nick == '') {
      nick = null;
    }

    final avatarCreator = _extractMsnObjectAttr(msnObject, 'Creator');
    final avatarSha1d = _extractMsnObjectAttr(msnObject, 'SHA1D');

    _rememberContact(
      email: email,
      displayName: nick ?? event.body,
      status: event.presence,
      avatarMsnObject: msnObject,
      avatarCreator: avatarCreator,
      avatarSha1d: avatarSha1d,
    );

    final normalizedEmail = email.trim().toLowerCase();
    // Contact came (back) online — clear any prior avatar-fetch failure so
    // the system retries automatically instead of staying permanently blocked.
    _avatarBackgroundFailed.remove(normalizedEmail);

    final normalizedSha1d = (avatarSha1d ?? '').trim();
    final normalizedMsnObj = (msnObject ?? '').trim();
    if (normalizedEmail.isNotEmpty &&
        normalizedSha1d.isNotEmpty &&
        normalizedMsnObj.isNotEmpty) {
      // ── Try fast HTTP fetch first (parallel, no SB lock needed) ──
      // Falls back to sequential P2P if the server doesn't have the avatar.
      _attemptHttpThenP2pAvatarFetch(
        contactEmail: normalizedEmail,
        avatarSha1d: normalizedSha1d,
        fullMsnObjectXml: normalizedMsnObj,
      );
    }
  }

  /// Tries HTTP first (fast, parallel) and falls back to P2P (sequential)
  /// if the server doesn't have the avatar cached.
  void _attemptHttpThenP2pAvatarFetch({
    required String contactEmail,
    required String avatarSha1d,
    required String fullMsnObjectXml,
  }) {
    final normalized = contactEmail.trim().toLowerCase();
    final sha = avatarSha1d.trim();
    if (normalized.isEmpty || sha.isEmpty) return;
    final dedupeKey = '$normalized|$sha';
    if (_avatarInviteSent.contains(dedupeKey)) return;
    // Don't add to _avatarInviteSent yet — only mark sent after success OR
    // after the P2P fallback is queued (so the P2P path still works).
    _p2pSessionManager.updateStatus(normalized, 'HTTP: Fetching avatar...');

    _rawSocketAvatarFetch(email: normalized, sha1d: sha)
        .then((path) {
          if (path != null) {
            _avatarInviteSent.add(dedupeKey);
            _onP2pAvatarReady(normalized, path, sha1d: sha);
          } else {
            _log('HTTP avatar miss for $normalized — falling back to P2P.');
            _p2pSessionManager.updateStatus(normalized, 'P2P: Queued...');
            _queueAvatarInvite(
              contactEmail: normalized,
              avatarSha1d: sha,
              fullMsnObjectXml: fullMsnObjectXml,
              eagerBackground: true,
            );
          }
        })
        .catchError((Object e) {
          _log('HTTP avatar error for $normalized: $e — falling back to P2P.');
          _p2pSessionManager.updateStatus(normalized, 'P2P: Queued...');
          _queueAvatarInvite(
            contactEmail: normalized,
            avatarSha1d: sha,
            fullMsnObjectXml: fullMsnObjectXml,
            eagerBackground: true,
          );
        });
  }

  /// Raw TCP socket fetch — bypasses Dart's URI normalisation so the
  /// lowercase percent-encoded SHA1D is sent unmodified to the server.
  Future<String?> _rawSocketAvatarFetch({
    required String email,
    required String sha1d,
  }) async {
    try {
      final encodedSha = Uri.encodeComponent(sha1d)
          .replaceAll('%2F', '%2f')
          .replaceAll('%3D', '%3d')
          .replaceAll('%2B', '%2b');

      final socket = await Socket.connect(
        '31.97.100.150',
        80,
      ).timeout(const Duration(seconds: 10));

      // Minimal headers matching the exact request that returned 200 OK.
      // socket.add() + flush() guarantees the request reaches the server before
      // we start listening — socket.write() alone may leave bytes buffered.
      final request =
          'GET /crosstalk/F126696BDBF6/$encodedSha HTTP/1.1\r\n'
          'Host: 31.97.100.150\r\n'
          'User-Agent: MSMSGS\r\n'
          'Connection: close\r\n'
          '\r\n';
      _log('[AVATAR] Fetching: /crosstalk/F126696BDBF6/$encodedSha');

      socket.add(utf8.encode(request));
      await socket.flush();

      final builder = BytesBuilder();
      await socket.listen(builder.add).asFuture<void>();
      socket.destroy();

      final responseBytes = builder.toBytes();

      // Find \r\n\r\n header/body boundary.
      int headerEnd = -1;
      for (int i = 0; i < responseBytes.length - 3; i++) {
        if (responseBytes[i] == 13 &&
            responseBytes[i + 1] == 10 &&
            responseBytes[i + 2] == 13 &&
            responseBytes[i + 3] == 10) {
          headerEnd = i + 4;
          break;
        }
      }
      if (headerEnd == -1 || headerEnd >= responseBytes.length) {
        _log('[AVATAR] No header boundary found for $email');
        return null;
      }

      // Parse header block (lowercased for easy contains checks).
      final headerText = utf8.decode(
        responseBytes.sublist(0, headerEnd),
        allowMalformed: true,
      );
      final headerLower = headerText.toLowerCase();

      // Verify HTTP 200. On failure log the full headers + first 400 chars of
      // body so we can see what URL the server actually expects.
      final statusLine = headerText.split('\r\n').first;
      if (!statusLine.contains('200')) {
        String bodyHint = '';
        if (headerEnd < responseBytes.length) {
          bodyHint = utf8
              .decode(
                responseBytes.sublist(
                  headerEnd,
                  (headerEnd + 400).clamp(0, responseBytes.length),
                ),
                allowMalformed: true,
              )
              .replaceAll('\n', ' ')
              .replaceAll('\r', '');
        }
        _log('[AVATAR] Non-200 for $email: $statusLine');
        _log('[AVATAR] Response headers:\n$headerText');
        _log('[AVATAR] Body hint: $bodyHint');
        return null;
      }

      List<int> rawBody = responseBytes.sublist(headerEnd);

      // CrossTalk may respond with HTTP/1.1 chunked encoding even when
      // we request HTTP/1.0. Decode the chunks if the header says so.
      if (headerLower.contains('transfer-encoding: chunked')) {
        _log('[AVATAR] Chunked response detected for $email — decoding');
        rawBody = _decodeChunkedBody(rawBody);
      }

      // Diagnostic: log first 8 bytes in hex so we can confirm image magic.
      final hexDump = rawBody
          .take(8)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      _log('[AVATAR] First 8 bytes for $email: $hexDump');

      final imageBytes = Uint8List.fromList(rawBody);
      if (imageBytes.length < 100) {
        _log('[AVATAR] Body too small (${imageBytes.length} bytes) for $email');
        return null;
      }

      // Write to the shared wlm_avatars cache dir.
      final root = await getTemporaryDirectory();
      final cacheDir = Directory(
        '${root.path}${Platform.pathSeparator}wlm_avatars',
      );
      if (!cacheDir.existsSync()) {
        await cacheDir.create(recursive: true);
      }
      final ext = _guessAvatarExtension(imageBytes);
      final filename = '${md5.convert(utf8.encode(sha1d))}.$ext';
      final file = File('${cacheDir.path}${Platform.pathSeparator}$filename');
      await file.writeAsBytes(imageBytes, flush: true);
      _log('[AVATAR] SUCCESS for $email → ${file.path}');
      return file.path;
    } catch (e) {
      _log('[AVATAR] Socket error for $email: $e');
      return null;
    }
  }

  /// Decodes an HTTP/1.1 chunked transfer-encoded body into raw bytes.
  List<int> _decodeChunkedBody(List<int> data) {
    final result = <int>[];
    int i = 0;
    while (i < data.length) {
      // Find end of chunk-size line (\r\n).
      int crLf = i;
      while (crLf < data.length - 1 &&
          !(data[crLf] == 13 && data[crLf + 1] == 10)) {
        crLf++;
      }
      if (crLf >= data.length - 1) break;

      // Parse hex chunk size (ignore optional chunk extensions after ';').
      final sizeLine = utf8
          .decode(data.sublist(i, crLf), allowMalformed: true)
          .split(';')
          .first
          .trim();
      final chunkSize = int.tryParse(sizeLine, radix: 16) ?? 0;
      if (chunkSize == 0) break; // terminal chunk

      final dataStart = crLf + 2;
      final dataEnd = dataStart + chunkSize;
      if (dataEnd > data.length) break;

      result.addAll(data.sublist(dataStart, dataEnd));
      i = dataEnd + 2; // skip trailing \r\n after chunk data
    }
    return result;
  }

  /// Makes a single raw TCP HTTP/1.1 GET request, bypassing Dart's Uri
  /// normalisation.  Returns the response body bytes on HTTP 200, or null.
  Future<Uint8List?> _rawSocketGet({
    required String host,
    required String ip,
    required int port,
    required String path,
    required String email,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        ip,
        port,
      ).timeout(const Duration(seconds: 10));
      final request =
          'GET $path HTTP/1.1\r\n'
          'Host: $host\r\n'
          'User-Agent: MSMSGS\r\n'
          'Connection: close\r\n'
          '\r\n';
      socket.add(utf8.encode(request));
      await socket.flush();

      final builder = BytesBuilder();
      await socket.listen(builder.add).asFuture<void>();
      final responseBytes = builder.toBytes();

      // Parse status line.
      final firstCrLf = _indexOfCrLf(responseBytes, 0);
      if (firstCrLf == -1) return null;
      final statusLine = utf8.decode(
        responseBytes.sublist(0, firstCrLf),
        allowMalformed: true,
      );
      final statusParts = statusLine.split(' ');
      if (statusParts.length < 2) return null;
      final code = statusParts[1];
      _log('[AVATAR] $code $path ($email)');
      if (code != '200') return null;

      // Slice off HTTP headers.
      int headerEnd = -1;
      for (int i = 0; i < responseBytes.length - 3; i++) {
        if (responseBytes[i] == 13 &&
            responseBytes[i + 1] == 10 &&
            responseBytes[i + 2] == 13 &&
            responseBytes[i + 3] == 10) {
          headerEnd = i + 4;
          break;
        }
      }
      if (headerEnd == -1 || headerEnd >= responseBytes.length) return null;

      final body = Uint8List.fromList(responseBytes.sublist(headerEnd));
      return body.length >= 100 ? body : null;
    } catch (e) {
      _log('[AVATAR] Socket error for $path: $e');
      return null;
    } finally {
      socket?.destroy();
    }
  }

  /// Returns the index of the first `\r\n` starting at [start], or -1.
  int _indexOfCrLf(Uint8List bytes, int start) {
    for (int i = start; i < bytes.length - 1; i++) {
      if (bytes[i] == 13 && bytes[i + 1] == 10) return i;
    }
    return -1;
  }

  String _guessAvatarExtension(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 6) {
      final head = ascii.decode(bytes.take(6).toList(), allowInvalid: true);
      if (head == 'GIF87a' || head == 'GIF89a') return 'gif';
    }
    return 'bin';
  }

  void _queueAvatarInvite({
    required String contactEmail,
    required String avatarSha1d,
    required String fullMsnObjectXml,
    required bool eagerBackground,
  }) {
    final normalizedEmail = contactEmail.trim().toLowerCase();
    final normalizedSha = avatarSha1d.trim();
    final normalizedObj = fullMsnObjectXml.trim();
    if (normalizedEmail.isEmpty ||
        normalizedSha.isEmpty ||
        normalizedObj.isEmpty) {
      return;
    }

    final dedupeKey = '$normalizedEmail|$normalizedSha';
    if (_avatarInviteSent.contains(dedupeKey)) {
      return;
    }

    _avatarInvitePending.add(normalizedEmail);

    if (!eagerBackground) {
      _avatarBackgroundFailed.remove(normalizedEmail);
    }

    if (_sbReady && _sbSocket != null && _sbContactEmail == normalizedEmail) {
      _trySendPendingAvatarInviteFor(normalizedEmail);
      return;
    }

    if (!eagerBackground) {
      return;
    }

    if (_avatarBackgroundFailed.contains(normalizedEmail)) {
      return;
    }

    if (_avatarSilentRequested.contains(dedupeKey)) {
      return;
    }
    _avatarSilentRequested.add(dedupeKey);
    // Lock the P2P pipeline immediately so _tryNextPendingAvatar won't fire
    // duplicate XFR requests while the switchboard is still being established.
    _sbP2pInFlightEmail ??= normalizedEmail;
    _sbIsSilentAvatarSession = true;
    _sbPendingRecipient = normalizedEmail;
    _ensureOutboundSwitchboard(normalizedEmail);
  }

  void _trySendPendingAvatarInviteFor(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return;
    }
    if (!_avatarInvitePending.contains(normalizedEmail)) {
      return;
    }
    final known = _knownContacts[normalizedEmail];
    final sha1d = (known?.avatarSha1d ?? '').trim();
    final fullMsnObj = (known?.avatarMsnObject ?? '').trim();
    if (sha1d.isEmpty || fullMsnObj.isEmpty) {
      return;
    }

    final sent = _sendDisplayPictureInvite(
      contactEmail: normalizedEmail,
      avatarSha1d: sha1d,
      fullMsnObjectXml: fullMsnObj,
    );
    if (sent) {
      _avatarInvitePending.remove(normalizedEmail);
    }
  }

  bool _sendDisplayPictureInvite({
    required String contactEmail,
    required String avatarSha1d,
    required String fullMsnObjectXml,
  }) {
    final normalizedEmail = contactEmail.trim().toLowerCase();
    if (!_sbReady || _sbSocket == null || _sbContactEmail != normalizedEmail) {
      return false;
    }

    final dedupeKey = '$contactEmail|$avatarSha1d';
    if (_avatarInviteSent.contains(dedupeKey)) {
      return false;
    }
    _avatarInviteSent.add(dedupeKey);
    _p2pSessionManager.updateStatus(normalizedEmail, 'P2P: Sending INVITE...');

    final inviteResult = _slpService.buildDisplayPictureInviteBinary(
      contactEmail: contactEmail,
      myEmail: _email,
      fullMsnObjectXml: fullMsnObjectXml,
    );

    // Persist GUIDs so we can build the SLP text ACK when the 200 OK arrives.
    _p2pSessionManager.storeInviteParams(
      peerEmail: normalizedEmail,
      callId: inviteResult.callId,
      branchId: inviteResult.branchId,
      sessionId: inviteResult.sessionId,
      baseId: inviteResult.baseId,
      sha1d: avatarSha1d,
    );

    final mimeHeaders =
        'MIME-Version: 1.0\r\n'
        'Content-Type: application/x-msnmsgrp2p\r\n'
        'P2P-Dest: $contactEmail\r\n'
        'P2P-Src: $_email\r\n\r\n';

    final payloadBytes = <int>[
      ...utf8.encode(mimeHeaders),
      ...inviteResult.bytes,
    ];
    // Log the full INVITE SLP text so it can be inspected in debug output.
    // Decode from the invite bytes: skip 48-byte header, read until 4-byte footer.
    try {
      final rawInvite = inviteResult.bytes;
      if (rawInvite.length > 52) {
        final slpPreview = utf8.decode(
          rawInvite.sublist(48, rawInvite.length - 4),
          allowMalformed: true,
        );
        print(
          '[MSNSLP][TX] INVITE SLP for $contactEmail callId=${inviteResult.callId} sessId=${inviteResult.sessionId}:\n$slpPreview',
        );
        // Hex dump of the 48-byte P2P binary header for wire-level debugging.
        final hdr = rawInvite.sublist(0, 48);
        final hexStr = hdr
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        print('[MSNSLP][TX] P2P-HDR (48 bytes): $hexStr');
        print(
          '[MSNSLP][TX] totalPayloadLen=${rawInvite.length} slpTextLen=${rawInvite.length - 52}',
        );
      }
    } catch (_) {}
    _sendSbMsgPayload(payloadBytes, debugLabel: mimeHeaders, msgFlag: 'D');
    _log(
      'Queued MSNSLP DP INVITE for $contactEmail sha1d=$avatarSha1d callId=${inviteResult.callId}',
    );
    _avatarSilentRequested.remove(dedupeKey);

    // Lock the SB for this contact until the transfer completes or times out.
    _sbP2pInFlightEmail = normalizedEmail;
    _sbP2pResponseTimeout?.cancel();
    _sbP2pResponseTimeout = Timer(const Duration(seconds: 15), () {
      if (_sbP2pInFlightEmail == normalizedEmail) {
        _log('P2P: 200 OK timeout waiting for $normalizedEmail — giving up.');
        _clearP2pInFlight(normalizedEmail);
        _markAvatarFetchFailed(normalizedEmail, reason: '200 OK timeout');
      }
    });
    // Start a 15-second stall timer that fails the transfer if no data arrives.
    _avatarStallTimers[normalizedEmail]?.cancel();
    _avatarStallTimers[normalizedEmail] = Timer(
      const Duration(seconds: 15),
      () {
        if (_sbP2pInFlightEmail == normalizedEmail) {
          _log('P2P: Avatar stall timeout for $normalizedEmail (15s no data).');
          _clearP2pInFlight(normalizedEmail);
          _markAvatarFetchFailed(normalizedEmail, reason: 'stall timeout');
        }
        _avatarStallTimers.remove(normalizedEmail);
      },
    );
    return true;
  }

  /// Handles an incoming SLP INVITE from the peer (transreqbody, sessionreqbody, etc.).
  void _handleIncomingSlpInvite(
    String from,
    String slpText, {
    int inviteBaseId = 0,
    int inviteTotalSize = 0,
  }) {
    final contentType = _extractSlpHeader(slpText, 'Content-Type') ?? '';
    final callId = _extractSlpHeader(slpText, 'Call-ID') ?? '';
    final branchId = _extractSlpHeader(slpText, 'Via');
    final sessionIdStr = _extractSlpBodyField(slpText, 'SessionID');
    final sessionId = int.tryParse(sessionIdStr ?? '') ?? 0;

    // Extract branch GUID from Via header: "MSNSLP/1.0/TLP ;branch={GUID}"
    String branch = '';
    if (branchId != null) {
      final branchMatch = RegExp(r'branch=(\{[^}]+\})').firstMatch(branchId);
      branch = branchMatch?.group(1) ?? '';
    }

    print(
      '[MSNSLP] Incoming INVITE from $from contentType=$contentType '
      'callId=$callId sessionId=$sessionId',
    );

    if (contentType.contains('transreqbody')) {
      // Transport negotiation — respond with 200 OK selecting SBBridge.
      // This unblocks the peer's P2P state machine so it can proceed with
      // our avatar transfer and/or send its own data via the switchboard.
      final responseBytes = _slpService.buildTransportResponse200(
        myEmail: _email,
        peerEmail: from,
        branchId: branch,
        callId: callId,
        sessionId: sessionId,
      );
      final mimeHeaders =
          'MIME-Version: 1.0\r\n'
          'Content-Type: application/x-msnmsgrp2p\r\n'
          'P2P-Dest: $from\r\n'
          'P2P-Src: $_email\r\n\r\n';
      final payload = <int>[...utf8.encode(mimeHeaders), ...responseBytes];
      _sendSbMsgPayload(
        payload,
        debugLabel: 'Transport 200 OK → $from callId=$callId bridge=SBBridge',
        msgFlag: 'D',
      );
      print(
        '[MSNSLP][TX] Transport 200 OK → $from callId=$callId bridge=SBBridge',
      );
    } else if (contentType.contains('sessionreqbody')) {
      // Check if this is a file transfer INVITE.
      final eufGuid = _extractSlpBodyField(slpText, 'EUF-GUID') ?? '';

      if (eufGuid.toUpperCase().contains('5D3E02AB')) {
        // ── File transfer INVITE ─────────────────────────────────────
        // Parse basic INVITE info needed for the frame-level baseId.
        final frameInfo = _slpService.parseInboundP2pFrame(
          utf8.encode(slpText),
        );
        final baseId = frameInfo?.baseId ?? Random().nextInt(0x7fffffff);

        final ftSession = _fileTransferService.parseIncomingInvite(
          slpText: slpText,
          from: from,
          baseId: baseId,
        );
        if (ftSession != null) {
          print(
            '[MSNSLP] File transfer INVITE from $from: '
            '${ftSession.fileName} (${ftSession.fileSize} bytes)',
          );
          // Emit event so the UI can present an accept/decline dialog.
          _eventController.add(
            MsnpEvent(
              type: MsnpEventType.system,
              command: 'FTINVITE',
              from: from,
              body: '${ftSession.sessionId}',
            ),
          );
        }
      } else if (eufGuid.toUpperCase().contains('A4268EEC')) {
        // ── Display picture (avatar) request ─────────────────────────
        _handleIncomingAvatarRequest(
          from,
          slpText,
          sessionId,
          callId,
          branch,
          inviteBaseId: inviteBaseId,
          inviteTotalSize: inviteTotalSize,
        );
      } else {
        // Unknown session type — decline.
        final declineText = [
          'MSNSLP/1.0 603 Decline',
          'To: <msnmsgr:$from>',
          'From: <msnmsgr:$_email>',
          'Via: MSNSLP/1.0/TLP ;branch=$branch',
          'CSeq: 1',
          'Call-ID: $callId',
          'Max-Forwards: 0',
          'Content-Type: application/x-msnmsgr-sessionreqbody',
          'Content-Length: 0',
          '',
          '',
        ].join('\r\n');
        final declinePayload = _slpService.buildP2pPayload(
          0,
          Random().nextInt(0x7fffffff),
          0,
          declineText,
        );
        final mimeHeaders =
            'MIME-Version: 1.0\r\n'
            'Content-Type: application/x-msnmsgrp2p\r\n'
            'P2P-Dest: $from\r\n'
            'P2P-Src: $_email\r\n\r\n';
        final payload = <int>[...utf8.encode(mimeHeaders), ...declinePayload];
        _sendSbMsgPayload(
          payload,
          debugLabel: 'SLP 603 Decline → $from callId=$callId',
          msgFlag: 'D',
        );
        print(
          '[MSNSLP][TX] 603 Decline → $from callId=$callId (inbound session)',
        );
      }
    } else if (contentType.contains('transrespbody')) {
      // The peer is responding to a transport negotiation — this is a
      // direct-connect offer (TRUDPv1 / TCPv1).  We don't support direct
      // connections; the transfer continues over the SB bridge, so we
      // simply acknowledge the response and let the data flow proceed.
      print(
        '[MSNSLP] Ignoring transrespbody INVITE from $from — data flows via SB bridge',
      );
    } else {
      print('[MSNSLP] Unhandled INVITE content-type from $from: $contentType');
    }
  }

  /// Extracts a header value from an SLP text block (e.g. "Call-ID: {GUID}").
  String? _extractSlpHeader(String slpText, String headerName) {
    final lines = slpText.split('\r\n');
    for (final line in lines) {
      if (line.isEmpty) break; // blank line = end of headers
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final name = line.substring(0, idx).trim();
      if (name.toLowerCase() == headerName.toLowerCase()) {
        return line.substring(idx + 1).trim();
      }
    }
    return null;
  }

  String? _extractMsnObjectAttr(String? msnObject, String name) {
    if (msnObject == null || msnObject.isEmpty) {
      return null;
    }
    final regex = RegExp('$name="([^"]+)"', caseSensitive: false);
    final match = regex.firstMatch(msnObject);
    if (match == null) {
      return null;
    }
    final value = (match.group(1) ?? '').trim();
    return value.isEmpty ? null : value;
  }

  /// Handle an incoming P2P INVITE for our display picture.
  /// Responds with 200 OK + sends the avatar data in chunks.
  void _handleIncomingAvatarRequest(
    String from,
    String slpText,
    int sessionId,
    String callId,
    String branch, {
    int inviteBaseId = 0,
    int inviteTotalSize = 0,
  }) {
    // Dedup: skip if we already started serving this session.
    if (_handledAvatarSessionIds.contains(sessionId)) {
      _log(
        'Avatar request from $from sessionId=$sessionId — DUPLICATE, skipping',
      );
      return;
    }
    _handledAvatarSessionIds.add(sessionId);
    _log('Avatar request from $from sessionId=$sessionId');

    // Use cached avatar path (set in updateSelfAvatarMsnObject) which is
    // always up-to-date. Falls back to SharedPreferences for robustness.
    Future<String?> resolveAvatarPath() async {
      if (_selfAvatarPath != null && File(_selfAvatarPath!).existsSync()) {
        return _selfAvatarPath;
      }
      return _getLocalAvatarPath();
    }

    resolveAvatarPath().then((avatarPath) async {
      if (avatarPath == null || !File(avatarPath).existsSync()) {
        _log(
          'No local avatar to serve → declining (path=${avatarPath ?? 'null'})',
        );
        _sendSlpDecline(from, branch, callId);
        return;
      }

      // Read avatar file and verify it's servable
      final avatarBytes = await File(avatarPath).readAsBytes();
      if (avatarBytes.isEmpty) {
        _log('Local avatar file is empty → declining');
        _sendSlpDecline(from, branch, callId);
        return;
      }

      // Log SHA1D of the file we're about to serve for interop diagnostics
      try {
        final contextMatch = RegExp(r'Context:\s*(\S+)').firstMatch(slpText);
        if (contextMatch != null) {
          _log(
            'Incoming avatar request Context (MSNObject): ${contextMatch.group(1)}',
          );
        }
      } catch (_) {}

      // Send 200 OK accepting the session — compute Content-Length dynamically.
      // NOTE: Do NOT include a trailing \x00 here — buildP2pPayload() already
      // null-terminates all SLP text on the wire.
      final sessionBody = 'SessionID: $sessionId\r\n\r\n';
      final sessionBodyBytes = utf8.encode(sessionBody);
      final okSlp = [
        'MSNSLP/1.0 200 OK',
        'To: <msnmsgr:$from>',
        'From: <msnmsgr:$_email>',
        'Via: MSNSLP/1.0/TLP ;branch=$branch',
        'CSeq: 1',
        'Call-ID: $callId',
        'Max-Forwards: 0',
        'Content-Type: application/x-msnmsgr-sessionreqbody',
        'Content-Length: ${sessionBodyBytes.length}',
        '',
        sessionBody,
      ].join('\r\n');

      final baseId = Random().nextInt(0x7fffffff);
      final prepBaseId = baseId + 1;
      final dataBaseId = baseId + 2;
      final okPayload = _slpService.buildP2pPayload(
        0,
        baseId,
        0,
        okSlp,
        ackSessionId: inviteBaseId,
        ackUniqueId: inviteBaseId,
        ackDataSize: inviteTotalSize,
      );
      final mimeOk =
          'MIME-Version: 1.0\r\n'
          'Content-Type: application/x-msnmsgrp2p\r\n'
          'P2P-Dest: $from\r\n'
          'P2P-Src: $_email\r\n\r\n';
      _sendSbMsgPayload(
        [...utf8.encode(mimeOk), ...okPayload],
        debugLabel:
            'Avatar 200 OK → $from session=$sessionId ackBase=$inviteBaseId',
        msgFlag: 'D',
      );
      _log('Sent avatar 200 OK to $from (ackBaseId=$inviteBaseId)');

      // Give the peer time to process the 200 OK and transition its P2P
      // state machine before we start sending the data-prep + data chunks.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // ── Data-prep packet ──────────────────────────────────────────
      // WLM 2009 requires a 4-byte data-preparation frame between the
      // 200 OK and the actual image data.  Without it the peer times
      // out (~90 s) and cancels the session with Flags=0x04.
      final dataPrepPayload = _slpService.buildDataPrepPacket(
        sessionId: sessionId,
        baseId: prepBaseId,
        footer: 1, // AppID 1 = display picture
      );
      final mimePrep =
          'MIME-Version: 1.0\r\n'
          'Content-Type: application/x-msnmsgrp2p\r\n'
          'P2P-Dest: $from\r\n'
          'P2P-Src: $_email\r\n\r\n';
      _sendSbMsgPayload(
        [...utf8.encode(mimePrep), ...dataPrepPayload],
        debugLabel: 'Avatar data-prep → $from session=$sessionId',
        msgFlag: 'D',
      );
      _log('Sent avatar data-prep to $from');

      // Small delay to let the peer process the data-prep before we
      // start streaming the actual image bytes.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Send data in 1202-byte chunks (max for SB relay)
      const maxChunk = 1202;
      int offset = 0;
      final totalSize = avatarBytes.length;

      while (offset < totalSize) {
        final chunkEnd = (offset + maxChunk).clamp(0, totalSize);
        final chunk = avatarBytes.sublist(offset, chunkEnd);

        final dataPayload = _slpService.buildP2pDataChunk(
          sessionId: sessionId,
          baseId: dataBaseId,
          offset: offset,
          totalSize: totalSize,
          chunkData: chunk,
          flags: 0x20, // data flag
        );
        final mimeData =
            'MIME-Version: 1.0\r\n'
            'Content-Type: application/x-msnmsgrp2p\r\n'
            'P2P-Dest: $from\r\n'
            'P2P-Src: $_email\r\n\r\n';
        _sendSbMsgPayload(
          [...utf8.encode(mimeData), ...dataPayload],
          debugLabel: 'Avatar data $offset-$chunkEnd/$totalSize → $from',
          msgFlag: 'D',
        );
        offset = chunkEnd;
        // Small yield to avoid flooding the SB socket
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      _log(
        'Avatar data fully sent to $from ($totalSize bytes in ${(totalSize / maxChunk).ceil()} chunks)',
      );

      // In MSN P2P, the RECEIVER (the party that sent the INVITE) is
      // responsible for sending BYE to close the session.  The SENDER
      // (us) must NOT send BYE — doing so before the peer processes &
      // validates the data (SHA1D check) causes WLM 2009 to discard
      // the received bytes and retry ~60 s later.
    });
  }

  /// Returns the local avatar file path from SharedPreferences.
  Future<String?> _getLocalAvatarPath() async {
    if (_email.isEmpty) {
      _log('_getLocalAvatarPath: email is empty — cannot look up avatar');
      return null;
    }
    final key = 'wlm_self_avatar_path_${_email.toLowerCase()}';
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(key);
    _log('_getLocalAvatarPath: key=$key → ${path ?? 'null'}');
    if (path != null && !File(path).existsSync()) {
      _log('_getLocalAvatarPath: file does not exist at $path');
      return null;
    }
    return path;
  }

  /// Send a generic SLP 603 decline.
  void _sendSlpDecline(String to, String branch, String callId) {
    final declineText = [
      'MSNSLP/1.0 603 Decline',
      'To: <msnmsgr:$to>',
      'From: <msnmsgr:$_email>',
      'Via: MSNSLP/1.0/TLP ;branch=$branch',
      'CSeq: 1',
      'Call-ID: $callId',
      'Max-Forwards: 0',
      'Content-Type: application/x-msnmsgr-sessionreqbody',
      'Content-Length: 0',
      '',
      '',
    ].join('\r\n');
    final payload = _slpService.buildP2pPayload(
      0,
      Random().nextInt(0x7fffffff),
      0,
      declineText,
    );
    final mime =
        'MIME-Version: 1.0\r\n'
        'Content-Type: application/x-msnmsgrp2p\r\n'
        'P2P-Dest: $to\r\n'
        'P2P-Src: $_email\r\n\r\n';
    _sendSbMsgPayload(
      [...utf8.encode(mime), ...payload],
      debugLabel: 'SLP 603 Decline → $to callId=$callId',
      msgFlag: 'D',
    );
  }

  String? _extractXmlTag(String payload, String tag) {
    final regex = RegExp(
      '<$tag>(.*?)</$tag>',
      dotAll: true,
      caseSensitive: false,
    );
    final match = regex.firstMatch(payload);
    if (match == null) {
      return null;
    }
    final raw = (match.group(1) ?? '').trim();
    return raw.isEmpty ? null : raw;
  }

  /// Like [_extractXmlTag] but returns empty string when the tag is present
  /// with no content (e.g. `<Scene></Scene>`). Returns null only when the tag
  /// is completely absent from the payload.
  String? _extractXmlTagAllowEmpty(String payload, String tag) {
    final regex = RegExp(
      '<$tag>(.*?)</$tag>',
      dotAll: true,
      caseSensitive: false,
    );
    final match = regex.firstMatch(payload);
    if (match == null) {
      return null;
    }
    return (match.group(1) ?? '').trim();
  }

  /// Extracts a `Key: Value` or `Key=Value` field from an MSNSLP body section.
  /// e.g. `_extractSlpBodyField(slp, 'SessionID')` → `'1234'`
  String? _extractSlpBodyField(String slpText, String key) {
    for (final line in slpText.split(RegExp(r'\r?\n'))) {
      // Try colon-space separator first (standard MSNSLP body format).
      final colon = line.indexOf(':');
      if (colon >= 1) {
        if (line.substring(0, colon).trim().toLowerCase() ==
            key.toLowerCase()) {
          return line.substring(colon + 1).trim();
        }
      }
      // Fall back to equals separator (some older clients use this).
      final eq = line.indexOf('=');
      if (eq >= 1) {
        if (line.substring(0, eq).trim().toLowerCase() == key.toLowerCase()) {
          return line.substring(eq + 1).trim();
        }
      }
    }
    return null;
  }

  /// Strips the MIME headers from [payloadBytes] and returns the raw P2P
  /// binary (starting with the 48-byte P2P transport header).
  List<int> _splitP2pBody(List<int> payloadBytes) {
    const crlfcrlf = [13, 10, 13, 10];
    for (var i = 0; i <= payloadBytes.length - 4; i++) {
      if (payloadBytes[i] == 13 &&
          payloadBytes[i + 1] == 10 &&
          payloadBytes[i + 2] == 13 &&
          payloadBytes[i + 3] == 10) {
        return payloadBytes.sublist(i + 4);
      }
    }
    return payloadBytes; // no headers found — return as-is
  }

  String? _parseCurrentMedia(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    final normalized = rawValue.replaceAll('\\0', '\u0000');
    final parts = normalized
        .split('\u0000')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return null;
    }

    if (parts.length >= 3) {
      final template = parts[2];
      final valueA = parts.length > 3 ? parts[3] : '';
      final valueB = parts.length > 4 ? parts[4] : '';

      if (template.contains('{0}') || template.contains('{1}')) {
        var rendered = template;
        if (valueA.isNotEmpty) {
          rendered = rendered.replaceAll('{0}', valueA);
        }
        if (valueB.isNotEmpty) {
          rendered = rendered.replaceAll('{1}', valueB);
        }
        rendered = rendered.trim();
        if (rendered.isNotEmpty &&
            !rendered.contains('{0}') &&
            !rendered.contains('{1}')) {
          return rendered;
        }
      }

      if (valueA.isNotEmpty && valueB.isNotEmpty) {
        return '$valueA - $valueB';
      }
      if (valueA.isNotEmpty) {
        return valueA;
      }

      final title = template;
      final artist = parts.length > 3 ? parts[3] : '';
      if (title.contains('{0}') ||
          title.contains('{1}') ||
          artist.contains('{0}') ||
          artist.contains('{1}')) {
        return null;
      }
      if (title.isNotEmpty && artist.isNotEmpty) {
        return '$title - $artist';
      }
      return title;
    }

    return parts.first;
  }

  void _startAbchRosterFetch({bool force = false}) {
    if (!_enableAbch) {
      return;
    }
    if (!force && _abchFetchStarted) {
      return;
    }
    if (_ticket.isEmpty && (_mspAuth ?? '').isEmpty) {
      return;
    }
    _abchFetchStarted = true;

    unawaited(() async {
      try {
        _log(
          'Starting ABCH roster fetch (SOAP). '
          'ticketLen=${_ticket.length}, mspAuthLen=${(_mspAuth ?? '').length}, sid=${_sid ?? '-'}',
        );
        final roster = await _abchService.fetchRoster(
          host: _connectedHost,
          ticket: _ticket,
          ownerEmail: _email,
          mspAuth: _mspAuth,
          mspProf: _mspProf,
          sid: _sid,
          log: (message) => _log(message),
        );

        if (roster.isEmpty) {
          _abchFetchReturnedEmpty = true;
          _log('ABCH roster fetch completed with no contacts.');
          if ((_mspAuth ?? '').isNotEmpty && !_abchRetryWithProfileTokensDone) {
            _abchRetryWithProfileTokensDone = true;
            _log(
              'Retrying ABCH fetch after empty result using profile-derived passport tokens.',
            );
            _abchFetchStarted = false;
            _startAbchRosterFetch(force: true);
            return;
          }
          _abchFetchStarted = false;
          return;
        }

        _abchFetchReturnedEmpty = false;

        for (final entry in roster) {
          final normalized = entry.email.toLowerCase();
          final existing = _knownContacts[normalized];
          _rememberContact(
            email: entry.email,
            displayName: entry.displayName,
            status: existing?.status ?? PresenceStatus.appearOffline,
          );
        }

        _sendAdlPresenceSubscription(roster);

        _eventController.add(
          MsnpEvent(
            type: MsnpEventType.system,
            command: 'ABCH',
            body: 'contacts=${roster.length}',
            raw: 'ABCH contacts=${roster.length}',
          ),
        );
        _log('ABCH roster fetch merged ${roster.length} contact(s).');
        _abchFetchStarted = false;
      } catch (error) {
        _log('ABCH roster fetch failed: $error');
        _abchFetchStarted = false;
      }
    }());
  }

  void _captureProfileTokens(String payload) {
    String? field(String key) {
      final regex = RegExp(
        '(?:^|\\r?\\n)$key:\\s*([^\\r\\n]+)',
        caseSensitive: false,
      );
      final match = regex.firstMatch(payload);
      if (match == null) {
        return null;
      }
      final value = (match.group(1) ?? '').trim();
      if (value.isEmpty) {
        return null;
      }
      return value;
    }

    final nextMspAuth = field('MSPAuth');
    final nextMspProf = field('MSPProf');
    final nextSid = field('sid');
    final nextMsnObjectRaw = field('MSNObject') ?? field('MsnObj');

    if (nextMspAuth != null && nextMspAuth.isNotEmpty) {
      _mspAuth = nextMspAuth;
    }
    if (nextMspProf != null && nextMspProf.isNotEmpty) {
      _mspProf = nextMspProf;
    }
    if (nextSid != null && nextSid.isNotEmpty) {
      _sid = nextSid;
    }
    if (nextMsnObjectRaw != null && nextMsnObjectRaw.isNotEmpty) {
      _selfAvatarMsnObject = Uri.decodeComponent(
        nextMsnObjectRaw.replaceAll('+', ' '),
      );
    } else {
      final embedded = _extractEmbeddedMsnObject(payload);
      if (embedded != null && embedded.isNotEmpty) {
        _selfAvatarMsnObject = embedded;
      }
    }

    if ((_mspAuth ?? '').isNotEmpty ||
        (_mspProf ?? '').isNotEmpty ||
        (_sid ?? '').isNotEmpty) {
      _log(
        'Profile tokens captured: '
        'MSPAuth=${_mspAuth == null ? 'no' : 'yes'}, '
        'MSPProf=${_mspProf == null ? 'no' : 'yes'}, '
        'sid=${_sid ?? '-'}',
      );

      if (!_enableAbch) {
        return;
      }

      if (_abchFetchReturnedEmpty && !_abchRetryWithProfileTokensDone) {
        _abchRetryWithProfileTokensDone = true;
        _log('Retrying ABCH fetch with profile-derived passport tokens.');
        _startAbchRosterFetch(force: true);
      } else if (!_abchFetchStarted) {
        _log('Triggering ABCH fetch now that profile tokens are available.');
        _startAbchRosterFetch(force: true);
      }
    }
  }

  void _sendAdlPresenceSubscription(List<AbchRosterEntry> roster) {
    if (_socket == null || roster.isEmpty) {
      return;
    }

    final byDomain = <String, Set<String>>{};
    for (final entry in roster) {
      final email = entry.email.trim().toLowerCase();
      if (!email.contains('@') || email == _email.toLowerCase()) {
        continue;
      }

      final split = email.split('@');
      if (split.length != 2) {
        continue;
      }

      final local = split.first.trim();
      final domain = split.last.trim();
      if (local.isEmpty || domain.isEmpty) {
        continue;
      }

      byDomain.putIfAbsent(domain, () => <String>{}).add(local);
    }

    if (byDomain.isEmpty) {
      return;
    }

    final xml = StringBuffer('<ml l="1">');
    final sortedDomains = byDomain.keys.toList()..sort();
    for (final domain in sortedDomains) {
      xml.write('<d n="${_escapeXmlAttr(domain)}">');
      final locals = byDomain[domain]!.toList()..sort();
      for (final local in locals) {
        xml.write('<c n="${_escapeXmlAttr(local)}" l="1" t="1" />');
      }
      xml.write('</d>');
    }
    xml.write('</ml>');

    final payload = xml.toString();
    _send(MsnpCommands.adl(_nextTrId(), payload));
    _log(
      'ADL presence subscription sent for ${roster.length} ABCH contact(s).',
    );
  }

  String _escapeXmlAttr(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String? _extractEmbeddedMsnObject(String payload) {
    final encoded = RegExp(
      r'(%3Cmsnobj[^\r\n]+%3E)',
      caseSensitive: false,
    ).firstMatch(payload)?.group(1);
    if (encoded != null && encoded.isNotEmpty) {
      return Uri.decodeComponent(encoded.replaceAll('+', ' '));
    }

    final raw = RegExp(
      r'(<msnobj[^\r\n]+>)',
      caseSensitive: false,
    ).firstMatch(payload)?.group(1);
    return raw;
  }
}

class MsnpContactSnapshot {
  const MsnpContactSnapshot({
    required this.email,
    required this.displayName,
    required this.status,
    this.personalMessage,
    this.nowPlaying,
    this.avatarMsnObject,
    this.avatarCreator,
    this.avatarSha1d,
    this.ddpMsnObject,
    this.ddpSha1d,
    this.scene,
    this.colorScheme,
  });

  final String email;
  final String displayName;
  final PresenceStatus status;
  final String? personalMessage;
  final String? nowPlaying;
  final String? avatarMsnObject;
  final String? avatarCreator;
  final String? avatarSha1d;
  final String? ddpMsnObject;
  final String? ddpSha1d;
  final String? scene;
  final String? colorScheme;
}

class _KnownContact {
  const _KnownContact({
    required this.email,
    required this.displayName,
    required this.status,
    this.personalMessage,
    this.nowPlaying,
    this.avatarMsnObject,
    this.avatarCreator,
    this.avatarSha1d,
    this.ddpMsnObject,
    this.ddpSha1d,
    this.scene,
    this.colorScheme,
  });

  final String email;
  final String displayName;
  final PresenceStatus status;
  final String? personalMessage;
  final String? nowPlaying;
  final String? avatarMsnObject;
  final String? avatarCreator;
  final String? avatarSha1d;
  final String? ddpMsnObject;
  final String? ddpSha1d;
  final String? scene;
  final String? colorScheme;

  _KnownContact copyWith({
    String? displayName,
    PresenceStatus? status,
    String? personalMessage,
    String? nowPlaying,
    String? avatarMsnObject,
    String? avatarCreator,
    String? avatarSha1d,
    String? ddpMsnObject,
    String? ddpSha1d,
    String? scene,
    String? colorScheme,
  }) {
    return _KnownContact(
      email: email,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      personalMessage: personalMessage ?? this.personalMessage,
      nowPlaying: nowPlaying ?? this.nowPlaying,
      avatarMsnObject: avatarMsnObject ?? this.avatarMsnObject,
      avatarCreator: avatarCreator ?? this.avatarCreator,
      avatarSha1d: avatarSha1d ?? this.avatarSha1d,
      ddpMsnObject: ddpMsnObject ?? this.ddpMsnObject,
      ddpSha1d: ddpSha1d ?? this.ddpSha1d,
      scene: scene ?? this.scene,
      colorScheme: colorScheme ?? this.colorScheme,
    );
  }
}

class _PendingFrame {
  const _PendingFrame({
    required this.command,
    required this.length,
    this.from,
    this.to,
  });

  final String command;
  final int length;
  final String? from;
  final String? to;

  factory _PendingFrame.fromHeader({
    required String headerLine,
    required int length,
    required String defaultTo,
  }) {
    final parts = headerLine.split(' ');
    final command = parts.first.toUpperCase();

    if (command == 'MSG') {
      return _PendingFrame(
        command: command,
        length: length,
        from: parts.length > 1 ? parts[1] : null,
        to: defaultTo,
      );
    }

    if (command == 'UBX') {
      return _PendingFrame(
        command: command,
        length: length,
        from: parts.length > 1 ? parts[1] : null,
      );
    }

    return _PendingFrame(command: command, length: length);
  }
}

class _ChallengeProfile {
  const _ChallengeProfile({
    required this.qryTarget,
    required this.productKey,
    required this.mode,
  });

  final String qryTarget;
  final String productKey;
  final _ChallengeMode mode;
}

class _PendingOutboundMessage {
  const _PendingOutboundMessage({
    required this.to,
    required this.payloadBytes,
    this.debugLabel,
    this.msgFlag = 'N',
    required this.fallbackToNotificationServer,
  });

  final String to;
  final List<int> payloadBytes;
  final String? debugLabel;
  final String msgFlag;
  final bool fallbackToNotificationServer;
}

enum _ChallengeMode { md5, msnp11 }
