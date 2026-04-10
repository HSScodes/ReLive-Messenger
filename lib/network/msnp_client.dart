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
import '../services/oim_service.dart';
import '../services/p2p_session_manager.dart';
import '../utils/challenge_utils.dart';
import '../utils/msnp_errors.dart';
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
  static const String _msnPecanProductKey = r'CFHUR$52U_{VIX5T';
  static const String endpointGuid = '{F91E6A6A-AF26-4A6A-8450-34D45A46DBCE}';
  static const int _maxConcurrentAvatarSbs = 8;

  static const List<_ChallengeProfile> _challengeProfiles = <_ChallengeProfile>[
    _ChallengeProfile(
      qryTarget: MsnpCommands.msnQryTargetWlm14,
      productKey: _wlm14ProductKey,
      mode: _ChallengeMode.md5,
    ),
    _ChallengeProfile(
      qryTarget: MsnpCommands.msnQryTargetMsnPecan,
      productKey: _msnPecanProductKey,
      mode: _ChallengeMode.msnp11,
    ),
  ];

  Socket? _socket;
  int _trId = 0;
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
  Timer? _pongTimeout;
  final List<int> _rxBuffer = <int>[];
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

  /// Pool of dedicated avatar SB connections keyed by normalised contact email.
  final Map<String, _AvatarSbConn> _avatarSbs = <String, _AvatarSbConn>{};

  /// XFR transaction IDs that were issued for dedicated avatar SBs (as opposed
  /// to the main chat SB).  Used by _handleXfr to route the response.
  final Set<int> _pendingAvatarXfrs = <int>{};

  /// Timeouts for pending avatar XFR requests so they don't block forever.
  final Map<int, Timer> _avatarXfrTimeouts = <int, Timer>{};

  /// Pool of chat SB connections keyed by normalised contact email.
  /// Each contact gets its own independent SB — no cross-contact contention.
  final Map<String, _ChatSbConn> _chatSbs = <String, _ChatSbConn>{};

  /// Contacts for which an XFR request has been sent but the SB endpoint has
  /// not yet been received.  Replaces the old scalar `_sbAwaitingXfr` flag.
  final Set<String> _chatSbPendingXfr = <String>{};

  /// Maximum concurrent chat SBs.  Oldest idle connection is evicted when
  /// this limit is reached.
  static const int _maxConcurrentChatSbs = 10;

  /// Periodic timer that evicts idle chat SBs (no activity for 3 min).
  Timer? _chatSbEvictionTimer;

  _PendingFrame? _pendingFrame;

  /// Per-contact avatar stall timers (15s timeout per avatar transfer).
  final Map<String, Timer> _avatarStallTimers = <String, Timer>{};

  /// Session IDs for which we already started serving our avatar.
  /// Prevents duplicate processing when the same INVITE is received
  /// multiple times on the same SB connection.
  final Set<int> _handledAvatarSessionIds = <int>{};

  /// Completers to await peer's data-complete ACK (Flags=0x02) per session.
  final Map<int, Completer<void>> _ftDataAckCompleters =
      <int, Completer<void>>{};

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

  // ── Auto-reconnect state ──────────────────────────────────────────────
  String _password = '';
  String _passportTicket = '';
  int _connectedPort = ServerConfig.port;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  int _pongMissCount = 0;
  static const int _maxPongMisses = 2;

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
  /// If the socket is dead, triggers an auto-reconnect attempt.
  void sendPing() {
    if (_socket == null) {
      _scheduleReconnect();
      return;
    }
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
    bool isAutoReconnect = false,
  }) async {
    _email = email.trim().toLowerCase();
    _connectedHost = host;
    _connectedPort = port;
    _password = password;
    _passportTicket = passportTicket;
    _keepAliveSeconds = 45;
    // Only reset reconnect counter on manual (user-initiated) connects.
    // Auto-reconnect must preserve the counter for exponential back-off.
    if (!isAutoReconnect) {
      _reconnectAttempts = 0;
    }
    _pongMissCount = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

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
    _destroyAllAvatarSbs();
    _destroyAllChatSbs();
    _log('Connecting to $host:$port for $email');

    _statusController.add(ConnectionStatus.connecting);

    try {
      _statusController.add(ConnectionStatus.authenticating);
      _ticket = await _resolveTicket(
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
      msgFlag: 'A',
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
      final chatConn = _chatSbs[normalized];
      if (chatConn?.p2pInFlightEmail != normalized &&
          !_avatarSbs.containsKey(normalized)) {
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
    _queueAvatarInvite(
      contactEmail: normalized,
      avatarSha1d: sha1d,
      fullMsnObjectXml: msnObj,
      eagerBackground: true,
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
    // Send a separate presence subscription (FL only) so the server sends
    // an ILN if the contact is currently online.  Some server implementations
    // do not treat the l="3" membership ADL as a presence subscription.
    final presPayload =
        '<ml l="1"><d n="$domain"><c n="$local" l="1" t="1" /></d></ml>';
    _send(MsnpCommands.adl(_nextTrId(), presPayload));
    _log('ADL presence subscription sent for $normalized');
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
        host: ServerConfig.abchHost,
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
      msgFlag: 'A',
      fallbackToNotificationServer: true,
    );
  }

  /// Invites another contact into the switchboard session for [intoSessionOf].
  void inviteToSwitchboard(String email, {required String intoSessionOf}) {
    final norm = intoSessionOf.trim().toLowerCase();
    final conn = _chatSbs[norm];
    if (conn == null || conn.socket == null || !conn.ready) {
      _log('Cannot invite $email — no active switchboard session for $norm.');
      return;
    }
    conn.send('CAL ${conn.nextTrId()} $email\r\n');
    _log('CAL sent for $email on SB[$norm]');
  }

  /// Leave the switchboard session for [contactEmail].
  Future<void> leaveSwitchboard(String contactEmail) async {
    final norm = contactEmail.trim().toLowerCase();
    final conn = _chatSbs[norm];
    if (conn == null) return;
    try {
      conn.send('OUT\r\n');
    } catch (_) {}
    _disconnectChatSb(norm);
    _log('Left switchboard session for $norm.');
  }

  /// Current switchboard participants for [contactEmail] (unmodifiable view).
  Set<String> sbParticipants(String contactEmail) {
    final norm = contactEmail.trim().toLowerCase();
    final conn = _chatSbs[norm];
    return Set<String>.unmodifiable(conn?.participants ?? <String>{});
  }

  /// True when the switchboard for [contactEmail] has more than one remote participant.
  bool isGroupSession(String contactEmail) {
    final norm = contactEmail.trim().toLowerCase();
    final conn = _chatSbs[norm];
    return (conn?.participants.length ?? 0) > 1;
  }

  /// Returns the SB key (contact email) for a group conversation by checking
  /// which active chat SB contains ALL the given [emails] as participants.
  /// Returns `null` if no matching SB is found.
  String? sbKeyForGroup(Iterable<String> emails) {
    final normalized = emails.map((e) => e.trim().toLowerCase()).toSet();
    for (final entry in _chatSbs.entries) {
      if (normalized.every((e) => entry.value.participants.contains(e))) {
        return entry.key;
      }
    }
    return null;
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
      final conn = _chatSbs[normalizedTo];
      if (conn != null && conn.ready && conn.socket != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    {
      final conn = _chatSbs[normalizedTo];
      if (conn == null || !conn.ready || conn.socket == null) {
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
    }

    // Wait for peer to process the data-prep.
    await Future<void>.delayed(const Duration(milliseconds: 80));

    // ── Send file data chunks directly (not via queue) ──────────────
    // Sending directly via _sendChatSbMsgPayload avoids all chunks being
    // queued and flushed at once by _flushChatSbQueue, ensuring the 30 ms
    // inter-chunk delay is honoured.
    for (final chunk in _fileTransferService.chunkFileForSending(
      sessionId: sessionId,
      fileBytes: fileBytes,
      baseId: dataBaseId,
    )) {
      final conn = _chatSbs[normalizedTo];
      if (conn == null || !conn.ready || conn.socket == null) {
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
      _sendChatSbMsgPayload(
        normalizedTo,
        [...utf8.encode(mimeHeaders), ...chunk],
        msgFlag: 'D',
      );
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

    final conn = _chatSbs[normalizedTo];
    if (conn != null && conn.ready && conn.socket != null && ftSession != null) {
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
      _sendChatSbMsgPayload(
        normalizedTo,
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
    cancelReconnect();
    _stopKeepAlive();
    _destroyAllAvatarSbs();
    _destroyAllChatSbs();
    if (_socket != null) {
      _send(MsnpCommands.out());
      await _socket!.close();
      _socket = null;
    }
    _statusController.add(ConnectionStatus.disconnected);
  }

  void dispose() {
    cancelReconnect();
    _stopKeepAlive();
    _destroyAllAvatarSbs();
    _destroyAllChatSbs();
    _chatSbEvictionTimer?.cancel();
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
      _stopKeepAlive();
      _statusController.add(ConnectionStatus.disconnected);
      _scheduleReconnect();
    } catch (error) {
      _log('Unexpected NS send failure: $error');
      _socket = null;
      _stopKeepAlive();
      _statusController.add(ConnectionStatus.disconnected);
      _scheduleReconnect();
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

    // If there's already an open, ready SB for this contact, send immediately.
    final conn = _chatSbs[normalizedTo];
    if (conn != null && conn.ready && conn.socket != null) {
      final trId = conn.sendMsgPayload(payloadBytes, msgFlag: msgFlag);
      if (debugLabel != null) {
        _logTx('[SB:$normalizedTo] MSG $trId $msgFlag ${payloadBytes.length}\r\n$debugLabel');
      }
      if (msgFlag.toUpperCase() == 'A') {
        conn.pendingAcks[trId] = normalizedTo;
      }
      if (fallbackToNotificationServer) {
        _bumpChatSbSendWatchdog(normalizedTo);
      }
      conn.lastActivity = DateTime.now();
      return;
    }

    final msg = _PendingOutboundMessage(
      to: normalizedTo,
      payloadBytes: payloadBytes,
      debugLabel: debugLabel,
      msgFlag: msgFlag,
      fallbackToNotificationServer: fallbackToNotificationServer,
    );

    // Ensure a _ChatSbConn stub exists for queueing messages.
    final target = _chatSbs.putIfAbsent(
      normalizedTo,
      () => _ChatSbConn(contactEmail: normalizedTo),
    );

    // Chat messages (non-'D') get priority over binary P2P data to avoid
    // noticeable input lag when a large file or avatar transfer is in
    // progress.  Insert them before the first P2P-flagged entry.
    if (msgFlag.toUpperCase() != 'D') {
      final firstP2p = target.outboundQueue.indexWhere(
        (m) => m.msgFlag.toUpperCase() == 'D',
      );
      if (firstP2p >= 0) {
        target.outboundQueue.insert(firstP2p, msg);
      } else {
        target.outboundQueue.add(msg);
      }
    } else {
      target.outboundQueue.add(msg);
    }
    _ensureOutboundChatSb(normalizedTo);
  }

  void _ensureOutboundChatSb(String recipient) {
    final conn = _chatSbs[recipient];

    // Already connecting or ready — nothing to do.
    if (conn != null && (conn.connecting || conn.ready)) return;

    // XFR already requested for this contact.
    if (_chatSbPendingXfr.contains(recipient)) return;

    // Guard against a duplicate XFR for the same recipient.
    if (_pendingXfrRequests.containsValue(recipient)) {
      _log('XFR already pending for $recipient — skipping duplicate request.');
      return;
    }

    _chatSbPendingXfr.add(recipient);
    final trId = _nextTrId();
    _pendingXfrRequests[trId] = recipient;
    _send('XFR $trId SB\r\n');
    _log('Requested switchboard endpoint for recipient $recipient.');
  }

  Future<void> _connectChatSb({
    required String host,
    required int port,
    required String authToken,
    required bool inviteMode,
    required String sessionId,
    required String contactEmail,
  }) async {
    final norm = contactEmail.trim().toLowerCase();

    // Ensure a conn object exists in the map.
    var conn = _chatSbs[norm];
    if (conn == null) {
      conn = _ChatSbConn(contactEmail: norm);
      _chatSbs[norm] = conn;
    }
    conn.connecting = true;

    try {
      // Tear down existing socket for this contact if any.
      _disconnectChatSb(norm, keepEntry: true);

      conn.connecting = true;
      conn.host = host;
      conn.port = port;
      conn.authToken = authToken;
      conn.sessionId = sessionId;
      conn.participants.clear();
      conn.isInviteMode = inviteMode;
      conn.ready = false;
      conn._trId = 0;
      conn.pendingFrame = null;
      conn.rxBuffer.clear();

      _log('Connecting chat SB to $host:$port for $norm.');

      // Evict idle SBs if we're at the limit (skip the one we're about to connect).
      _evictIdleChatSbs(exclude: norm);

      conn.socket = await Socket.connect(
        host,
        port,
        timeout: ServerConfig.connectTimeout,
      );
      conn.socket!.listen(
        (data) => _onChatSbData(norm, data),
        onDone: () => _onChatSbDone(norm),
        onError: (e) => _onChatSbError(norm, e),
        cancelOnError: false,
      );

      if (inviteMode) {
        conn.send('ANS ${conn.nextTrId()} $_email $authToken $sessionId\r\n');
      } else {
        conn.send('USR ${conn.nextTrId()} $_email $authToken\r\n');
      }
    } on Object catch (error) {
      _log('Failed to connect chat SB for $norm: $error');
      conn.ready = false;
    } finally {
      conn.connecting = false;
      _chatSbPendingXfr.remove(norm);
    }
  }

  void _disconnectChatSb(String email, {bool keepEntry = false}) {
    final conn = _chatSbs[email];
    if (conn == null) return;
    try {
      conn.send('OUT\r\n');
    } catch (_) {}
    conn.destroy();
    if (!keepEntry) {
      _chatSbs.remove(email);
    }
  }

  /// Destroy all chat SBs (e.g. on disconnect/reconnect).
  void _destroyAllChatSbs() {
    for (final conn in _chatSbs.values) {
      try {
        conn.send('OUT\r\n');
      } catch (_) {}
      conn.destroy();
    }
    _chatSbs.clear();
    _chatSbPendingXfr.clear();
    _chatSbEvictionTimer?.cancel();
    _chatSbEvictionTimer = null;
  }

  /// Evicts the oldest idle chat SBs so the pool stays within
  /// [_maxConcurrentChatSbs].  Connections with pending outbound messages
  /// or active P2P transfers are kept.  [exclude] is never evicted.
  void _evictIdleChatSbs({required String exclude}) {
    if (_chatSbs.length < _maxConcurrentChatSbs) return;

    // Sort entries by lastActivity ascending (oldest first).
    final candidates = _chatSbs.entries
        .where((e) =>
            e.key != exclude &&
            e.value.outboundQueue.isEmpty &&
            e.value.p2pInFlightEmail == null)
        .toList()
      ..sort((a, b) => a.value.lastActivity.compareTo(b.value.lastActivity));

    while (_chatSbs.length >= _maxConcurrentChatSbs && candidates.isNotEmpty) {
      final victim = candidates.removeAt(0);
      _log('Evicting idle chat SB for ${victim.key}');
      _disconnectChatSb(victim.key);
    }
  }

  /// Send a MSG payload on the chat SB for [email].  Returns the trId.
  int _sendChatSbMsgPayload(
    String email,
    List<int> payloadBytes, {
    String? debugLabel,
    String msgFlag = 'N',
  }) {
    final conn = _chatSbs[email];
    if (conn == null || conn.socket == null) return 0;
    final upper = msgFlag.toUpperCase();
    final flag = (upper == 'D') ? 'D' : (upper == 'A') ? 'A' : 'N';
    final trId = conn.sendMsgPayload(payloadBytes, msgFlag: flag);
    if (debugLabel != null && debugLabel.isNotEmpty) {
      _logTx('[SB:$email] MSG $trId $flag ${payloadBytes.length}\r\n$debugLabel');
    } else {
      _logTx('[SB:$email] MSG $trId $flag <binary:${payloadBytes.length}>');
    }
    conn.lastActivity = DateTime.now();
    return trId;
  }

  void _onChatSbData(String email, List<int> data) {
    final conn = _chatSbs[email];
    if (conn == null) return;

    // Any data from the SB server resets the send watchdog — the SB is alive.
    conn.sendWatchdog?.cancel();
    conn.sendWatchdog = null;
    conn.unackedTextSinceRx = 0;
    conn.lastActivity = DateTime.now();

    conn.rxBuffer.addAll(data);

    while (true) {
      if (conn.pendingFrame != null) {
        final pending = conn.pendingFrame!;
        if (conn.rxBuffer.length < pending.length) {
          return;
        }

        final payloadBytes = conn.rxBuffer.sublist(0, pending.length);
        conn.rxBuffer.removeRange(0, pending.length);
        final payload = utf8.decode(payloadBytes, allowMalformed: true);
        _handleChatSbPayload(email, pending, payload, payloadBytes);
        conn.pendingFrame = null;
        _trimLeadingCrlf(conn.rxBuffer);
        continue;
      }

      final splitIndex = _indexOfCrlf(conn.rxBuffer);
      if (splitIndex == -1) {
        return;
      }

      final lineBytes = conn.rxBuffer.sublist(0, splitIndex);
      conn.rxBuffer.removeRange(0, splitIndex + 2);
      final line = utf8.decode(lineBytes, allowMalformed: true);
      if (line.isEmpty) {
        continue;
      }

      _logRx('[SB:$email] $line');
      final pendingLength = _extractPayloadLength(line);
      if (pendingLength != null) {
        _handleChatSbLine(email, line);
        conn.pendingFrame = _PendingFrame.fromHeader(
          headerLine: line,
          length: pendingLength,
          defaultTo: _email,
        );
        continue;
      }

      _handleChatSbLine(email, line);
    }
  }

  void _handleChatSbLine(String contactEmail, String line) {
    final conn = _chatSbs[contactEmail];
    if (conn == null) return;

    final parts = line.trim().split(' ');
    if (parts.isEmpty) {
      return;
    }

    final command = parts.first.toUpperCase();
    if (command == 'JOI' && parts.length > 1) {
      conn.joinTimeout?.cancel();
      conn.joinTimeout = null;
      final email = parts[1].toLowerCase();
      conn.participants.add(email);
      if (email.contains('@')) {
        _rememberContact(
          email: email,
          displayName: email,
          status: PresenceStatus.online,
        );
        _eventController.add(
          MsnpEvent(type: MsnpEventType.system, command: 'SBJOIN', from: email, to: contactEmail),
        );
      }
      conn.ready = true;
      _flushChatSbQueue(contactEmail);
      _trySendPendingAvatarInviteFor(email);
      return;
    }

    if (command == 'IRO' && parts.length > 4) {
      conn.joinTimeout?.cancel();
      conn.joinTimeout = null;
      // IRO format: IRO trId index total email [friendlyname]
      final email = parts[4].toLowerCase();
      conn.participants.add(email);
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
      if (conn.isInviteMode) {
        conn.ready = true;
        _flushChatSbQueue(contactEmail);
        _trySendPendingAvatarInviteFor(email);
      }
      return;
    }

    if (command == 'ANS' || command == 'USR') {
      if (command == 'ANS' && conn.isInviteMode) {
        conn.ready = true;
        _flushChatSbQueue(contactEmail);
        return;
      }

      conn.ready = false;
      if (command == 'USR' && !conn.isInviteMode) {
        conn.send('CAL ${conn.nextTrId()} $contactEmail\r\n');
        _startChatSbJoinTimeout(contactEmail);
      }
      return;
    }

    // ── ACK — server confirmed receipt of our MSG ─────────────────
    if (command == 'ACK' && parts.length > 1) {
      final trId = int.tryParse(parts[1]);
      if (trId != null) {
        conn.pendingAcks.remove(trId);
      }
      return;
    }

    // ── NAK — server could not deliver our MSG ──────────────────
    if (command == 'NAK' && parts.length > 1) {
      final trId = int.tryParse(parts[1]);
      if (trId != null) {
        final recipient = conn.pendingAcks.remove(trId);
        _log('NAK for trId=$trId recipient=$recipient — message not delivered');
        if (recipient != null) {
          _eventController.add(MsnpEvent(
            type: MsnpEventType.system,
            command: 'MSGNAK',
            from: recipient,
            body: 'trId=$trId',
          ));
        }
      }
      // NAK means the peer can't receive — tear down this SB.
      _log('Tearing down SB[$contactEmail] after NAK — peer unreachable.');
      final remaining = conn.pendingAcks.length;
      if (remaining > 0) {
        _eventController.add(MsnpEvent(
          type: MsnpEventType.system,
          command: 'SBSTALE',
          from: contactEmail,
          body: '$remaining',
        ));
      }
      _disconnectChatSb(contactEmail);
      return;
    }

    if (command == 'BYE' && parts.length > 1) {
      final who = parts[1].toLowerCase();
      _log('SB[$contactEmail] peer left: $who');
      conn.participants.remove(who);
      // When ALL participants have left, tear down.
      if (conn.participants.isEmpty) {
        if (conn.pendingAcks.isNotEmpty) {
          final count = conn.pendingAcks.length;
          _log('BYE emptied SB[$contactEmail] with $count unacked message(s)');
          _eventController.add(MsnpEvent(
            type: MsnpEventType.system,
            command: 'SBSTALE',
            from: who,
            body: '$count',
          ));
        }
        _disconnectChatSb(contactEmail);
      }
      if (who.contains('@')) {
        _rememberContact(
          email: who,
          displayName: who,
          status: PresenceStatus.appearOffline,
        );
        _eventController.add(
          MsnpEvent(type: MsnpEventType.system, command: 'SBLEAVE', from: who, to: contactEmail),
        );
      }
    }
  }

  void _handleChatSbPayload(
    String sbEmail,
    _PendingFrame frame,
    String payload,
    List<int> payloadBytes,
  ) {
    if (frame.command != 'MSG') {
      return;
    }

    final from = (frame.from ?? sbEmail).toLowerCase();
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
          _sendChatSbMsgPayload(
            sbEmail,
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
          _sendChatSbMsgPayload(
            sbEmail,
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
                  _clearChatSbP2pInFlight(normFrom);
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
            _sendChatSbMsgPayload(
              sbEmail,
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
            final _p2pConn = _chatSbs[sbEmail];
            if (_p2pConn != null) {
              _p2pConn.p2pResponseTimeout?.cancel();
              _p2pConn.p2pResponseTimeout = null;
            }
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
              _sendChatSbMsgPayload(
                sbEmail,
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

    var event = MsnpParser.parseMsgPayload(
      from: from,
      to: _email,
      payload: payload,
    );
    // Attach the SB connection key so consumers can look up group/participants.
    if (sbEmail != from) {
      event = MsnpEvent(
        type: event.type,
        command: event.command,
        from: event.from,
        to: event.to,
        body: event.body,
        presence: event.presence,
        raw: 'sbKey:$sbEmail',
      );
    }
    _eventController.add(event);
  }

  void _flushChatSbQueue(String email) {
    final conn = _chatSbs[email];
    if (conn == null || !conn.ready || conn.socket == null) {
      return;
    }

    final sent = <_PendingOutboundMessage>[];
    for (final pending in conn.outboundQueue) {
      final trId = _sendChatSbMsgPayload(
        email,
        pending.payloadBytes,
        debugLabel: pending.debugLabel,
        msgFlag: pending.msgFlag,
      );
      if (pending.msgFlag.toUpperCase() == 'A') {
        conn.pendingAcks[trId] = pending.to;
      }
      if (pending.fallbackToNotificationServer) {
        _bumpChatSbSendWatchdog(email);
      }
      sent.add(pending);
    }
    for (final item in sent) {
      conn.outboundQueue.remove(item);
    }
  }

  void _trimLeadingCrlf(List<int> buffer) {
    while (buffer.length >= 2 &&
        buffer[0] == 13 &&
        buffer[1] == 10) {
      buffer.removeRange(0, 2);
    }
  }

  void _handleRng(String line) {
    final parts = line.trim().split(' ');
    if (parts.length < 7) {
      _log('Received malformed RNG: $line');
      return;
    }

    final contactEmail = parts[5].toLowerCase();
    final sessionId = parts[1];
    final hostPort = parts[2];
    final authToken = parts[4];

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

    // Multi-SB: if there's already an SB for this contact, tear it down and
    // replace.  Other contacts' SBs are unaffected.
    if (_chatSbs.containsKey(contactEmail)) {
      _log('RNG from $contactEmail — replacing existing SB.');
      _disconnectChatSb(contactEmail);
    }

    unawaited(
      _connectChatSb(
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
      _log('Received malformed XFR: $line');
      return;
    }

    final trId = int.tryParse(parts[1]);
    if (trId == null) {
      _log('Received XFR with invalid transaction id: $line');
      return;
    }

    // Cancel avatar XFR timeout if this was an avatar request.
    _avatarXfrTimeouts.remove(trId)?.cancel();

    if (parts[2].toUpperCase() != 'SB') {
      _pendingXfrRequests.remove(trId);
      return;
    }

    final hostPort = parts[3];
    final authToken = parts[5];
    final hostParts = hostPort.split(':');
    final recipient = _pendingXfrRequests.remove(trId);
    if (hostParts.length != 2 || recipient == null || recipient.isEmpty) {
      _log('Unable to use XFR for switchboard: $line');
      return;
    }

    final port = int.tryParse(hostParts[1]);
    if (port == null) {
      _pendingAvatarXfrs.remove(trId);
      _chatSbPendingXfr.remove(recipient);
      _log('XFR provided invalid port: $hostPort');
      return;
    }

    // Route to the dedicated avatar SB pool if this XFR was requested for an
    // avatar transfer, otherwise to the chat SB for the recipient.
    if (_pendingAvatarXfrs.remove(trId)) {
      unawaited(
        _connectAvatarSb(
          email: recipient,
          host: hostParts[0],
          port: port,
          authToken: authToken,
        ),
      );
    } else {
      _chatSbPendingXfr.remove(recipient);
      unawaited(
        _connectChatSb(
          host: hostParts[0],
          port: port,
          authToken: authToken,
          inviteMode: false,
          sessionId: '',
          contactEmail: recipient,
        ),
      );
    }
  }

  /// Increments the watchdog counter and starts the 15 s timer if needed.
  void _bumpChatSbSendWatchdog(String email) {
    final conn = _chatSbs[email];
    if (conn == null) return;
    conn.unackedTextSinceRx++;
    if (conn.sendWatchdog == null) {
      conn.sendWatchdog = Timer(
        const Duration(seconds: 15),
        () => _onChatSbSendWatchdog(email),
      );
    }
  }

  void _onChatSbSendWatchdog(String email) {
    final conn = _chatSbs[email];
    if (conn == null) return;
    conn.sendWatchdog = null;
    if (conn.unackedTextSinceRx >= 2 && conn.socket != null) {
      _log(
        'SB[$email] send watchdog: ${conn.unackedTextSinceRx} texts sent with '
        'no server response for 15s — tearing down stale SB.',
      );
      final count = conn.unackedTextSinceRx;
      _disconnectChatSb(email);
      _eventController.add(
        MsnpEvent(
          type: MsnpEventType.system,
          command: 'SBSTALE',
          from: email,
          body: '$count',
        ),
      );
    }
  }

  void _onChatSbDone(String email) {
    final conn = _chatSbs[email];
    // If connecting, this is a stale callback from an old socket being replaced.
    if (conn != null && conn.connecting) {
      _log('SB[$email] closed (stale — reconnect in progress).');
      return;
    }
    _log('SB[$email] closed by remote endpoint.');

    // Report any text messages that never received ACK.
    if (conn != null && conn.pendingAcks.isNotEmpty) {
      final count = conn.pendingAcks.length;
      _log('SB[$email] closed with $count unacked text message(s)');
      _eventController.add(MsnpEvent(
        type: MsnpEventType.system,
        command: 'SBSTALE',
        from: email,
        body: '$count',
      ));
    }

    // Fail active incoming file transfers on this SB.
    _fileTransferService.failActiveSessionsForPeer(email);

    // If a P2P transfer was in-flight, re-queue for retry.
    if (conn?.p2pInFlightEmail == email) {
      _p2pSessionManager.closeAllSessionsForPeer(email);
      _clearChatSbP2pInFlight(email);
      final retries = _avatarSbRetryCount[email] ?? 0;
      if (retries < 5) {
        _avatarSbRetryCount[email] = retries + 1;
        _log('SB[$email] closed while P2P in-flight — re-queuing (retry ${retries + 1}/5).');
        _avatarInvitePending.add(email);
        _avatarInviteSent.removeWhere((k) => k.startsWith('$email|'));
        _avatarSilentRequested.removeWhere((k) => k.startsWith('$email|'));
      } else {
        _markAvatarFetchFailed(email, reason: 'SB closed before transfer completed (after $retries retries)');
      }
    }

    _disconnectChatSb(email);
    _tryNextPendingAvatar();
  }

  void _onChatSbError(String email, Object error) {
    _log('SB[$email] socket error: $error');

    final conn = _chatSbs[email];
    if (conn != null && conn.pendingAcks.isNotEmpty) {
      final count = conn.pendingAcks.length;
      _log('SB[$email] error with $count unacked text message(s)');
      _eventController.add(MsnpEvent(
        type: MsnpEventType.system,
        command: 'SBSTALE',
        from: email,
        body: '$count',
      ));
    }

    _fileTransferService.failActiveSessionsForPeer(email);

    if (conn?.p2pInFlightEmail == email) {
      _clearChatSbP2pInFlight(email);
      final retries = _avatarSbRetryCount[email] ?? 0;
      if (retries < 5) {
        _avatarSbRetryCount[email] = retries + 1;
        _log('SB[$email] error while P2P in-flight — re-queuing (retry ${retries + 1}/5).');
        _avatarInvitePending.add(email);
        _avatarInviteSent.removeWhere((k) => k.startsWith('$email|'));
        _avatarSilentRequested.removeWhere((k) => k.startsWith('$email|'));
      } else {
        _markAvatarFetchFailed(email, reason: 'SB socket error (after $retries retries)');
      }
    }

    _disconnectChatSb(email);
    _tryNextPendingAvatar();
  }

  void _startChatSbJoinTimeout(String contactEmail) {
    final norm = contactEmail.trim().toLowerCase();
    final conn = _chatSbs[norm];
    if (conn == null) return;
    conn.joinTimeout?.cancel();
    conn.joinTimeout = Timer(const Duration(seconds: 6), () => _onChatSbJoinTimeout(norm));
  }

  void _onChatSbJoinTimeout(String email) {
    final conn = _chatSbs[email];
    if (conn == null) return;
    conn.joinTimeout = null;
    _log('SB[$email] JOI timeout — peer did not join within 6s.');
    _disconnectChatSb(email);
  }

  void _markAvatarFetchFailed(
    String contactEmail, {
    required String reason,
  }) {
    final failedContact = contactEmail.trim().toLowerCase();
    if (failedContact.isEmpty) return;

    _log('Avatar fetch failed for $failedContact: $reason');

    _avatarInvitePending.remove(failedContact);
    _avatarBackgroundFailed.add(failedContact);
    _avatarSilentRequested.removeWhere(
      (key) => key.startsWith('$failedContact|'),
    );
    _avatarInviteSent.removeWhere((key) => key.startsWith('$failedContact|'));

    _eventController.add(
      MsnpEvent(
        type: MsnpEventType.system,
        command: 'AVFAIL',
        from: failedContact,
        raw: 'AVFAIL $failedContact',
      ),
    );
    // Tear down dedicated avatar SB if one exists for this contact.
    _destroyAvatarSb(failedContact);
    // Release the in-flight lock and kick off the next pending transfer.
    _clearChatSbP2pInFlight(failedContact);
    _tryNextPendingAvatar();
  }

  /// Releases the P2P in-flight lock for [email] on the per-contact chat SB.
  void _clearChatSbP2pInFlight(String email) {
    final conn = _chatSbs[email];
    if (conn != null && conn.p2pInFlightEmail == email) {
      conn.p2pResponseTimeout?.cancel();
      conn.p2pResponseTimeout = null;
      conn.p2pInFlightEmail = null;
      _avatarStallTimers[email]?.cancel();
      _avatarStallTimers.remove(email);
      _log('Chat SB P2P in-flight lock released for $email');
    }
  }

  /// After a transfer completes or fails, start the next avatar fetch from
  /// any remaining contacts still in [_avatarInvitePending].
  /// Fills the avatar SB pool up to [_maxConcurrentAvatarSbs] concurrent
  /// connections.
  void _tryNextPendingAvatar() {
    final pending = _avatarInvitePending.toList();
    for (final email in pending) {
      // Stop when the pool is full.
      if (_avatarSbs.length >= _maxConcurrentAvatarSbs) return;
      if (_avatarBackgroundFailed.contains(email)) continue;
      if (_avatarSbs.containsKey(email)) continue; // already active
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
    }
  }

  /// Called by [_p2pSessionManager] when a display picture is fully reassembled.
  void _onP2pAvatarReady(String peerEmail, String filePath, {String? sha1d}) {
    final normalized = peerEmail.trim().toLowerCase();
    _log('P2P avatar ready for $normalized → $filePath');
    // Release the in-flight lock so the next queued contact can start.
    _clearChatSbP2pInFlight(normalized);
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
    // Tear down the dedicated avatar SB for this contact.
    _destroyAvatarSb(normalized);
    // Start the next pending avatar transfer for OTHER contacts.
    _tryNextPendingAvatar();
  }

  // ── Dedicated Avatar SB Pool ──────────────────────────────────────────

  /// Sends an XFR SB request on the NS for a dedicated avatar switchboard
  /// connection.  The resulting XFR response is routed by [_handleXfr] to
  /// [_connectAvatarSb] instead of the main SB.
  void _requestAvatarSb(String email) {
    final norm = email.trim().toLowerCase();
    if (_avatarSbs.containsKey(norm)) return;
    if (_avatarSbs.length >= _maxConcurrentAvatarSbs) return;
    // Guard against a duplicate XFR for the same recipient.
    if (_pendingXfrRequests.containsValue(norm)) return;
    if (_socket == null) return;

    final trId = _nextTrId();
    _pendingXfrRequests[trId] = norm;
    _pendingAvatarXfrs.add(trId);
    _avatarXfrTimeouts[trId] = Timer(const Duration(seconds: 10), () {
      _avatarXfrTimeouts.remove(trId);
      _pendingXfrRequests.remove(trId);
      _pendingAvatarXfrs.remove(trId);
      _log('Avatar XFR timeout for $norm (trId=$trId) — cleared pending state.');
    });
    _send('XFR $trId SB\r\n');
    _log('Requested dedicated avatar SB for $norm (XFR trId=$trId).');
  }

  /// Opens a dedicated avatar SB TCP connection, authenticates, and CALs
  /// the contact.
  Future<void> _connectAvatarSb({
    required String email,
    required String host,
    required int port,
    required String authToken,
  }) async {
    final norm = email.trim().toLowerCase();
    // If a connection already exists for this contact, destroy it first.
    _destroyAvatarSb(norm);

    final conn = _AvatarSbConn(contactEmail: norm);
    conn.connecting = true;
    _avatarSbs[norm] = conn;

    try {
      _log('Connecting avatar SB to $host:$port for $norm');
      conn.socket = await Socket.connect(
        host,
        port,
        timeout: ServerConfig.connectTimeout,
      );
      conn.socket!.listen(
        (data) => _onAvatarSbData(norm, data),
        onDone: () => _onAvatarSbDone(norm),
        onError: (e, s) => _onAvatarSbError(norm, e),
        cancelOnError: false,
      );
      conn.send('USR ${conn.nextTrId()} $_email $authToken\r\n');
    } catch (e) {
      _log('Failed to connect avatar SB for $norm: $e');
      _destroyAvatarSb(norm);
      _markAvatarFetchFailed(norm, reason: 'avatar SB connect failed');
    } finally {
      conn.connecting = false;
    }
  }

  void _onAvatarSbData(String email, List<int> data) {
    final conn = _avatarSbs[email];
    if (conn == null) return;
    conn.rxBuffer.addAll(data);

    while (true) {
      // Pending binary frame.
      if (conn.pendingFrame != null) {
        final pending = conn.pendingFrame!;
        if (conn.rxBuffer.length < pending.length) return;
        final payloadBytes = conn.rxBuffer.sublist(0, pending.length);
        conn.rxBuffer.removeRange(0, pending.length);
        final payload = utf8.decode(payloadBytes, allowMalformed: true);
        _handleAvatarSbPayload(conn, pending, payload, payloadBytes);
        conn.pendingFrame = null;
        // Trim leading CRLF separators.
        while (conn.rxBuffer.length >= 2 &&
            conn.rxBuffer[0] == 13 &&
            conn.rxBuffer[1] == 10) {
          conn.rxBuffer.removeRange(0, 2);
        }
        continue;
      }

      final splitIndex = _indexOfCrlf(conn.rxBuffer);
      if (splitIndex == -1) return;

      final lineBytes = conn.rxBuffer.sublist(0, splitIndex);
      conn.rxBuffer.removeRange(0, splitIndex + 2);
      final line = utf8.decode(lineBytes, allowMalformed: true);
      if (line.isEmpty) continue;

      _logRx('[AV-SB:$email] $line');
      final pendingLength = _extractPayloadLength(line);
      if (pendingLength != null) {
        _handleAvatarSbLine(conn, line);
        conn.pendingFrame = _PendingFrame.fromHeader(
          headerLine: line,
          length: pendingLength,
          defaultTo: _email,
        );
        continue;
      }
      _handleAvatarSbLine(conn, line);
    }
  }

  void _handleAvatarSbLine(_AvatarSbConn conn, String line) {
    final parts = line.trim().split(' ');
    if (parts.isEmpty) return;
    final command = parts.first.toUpperCase();

    if (command == 'USR') {
      // USR OK — send CAL to invite the contact.
      conn.send('CAL ${conn.nextTrId()} ${conn.contactEmail}\r\n');
      _log('[AV-SB] USR OK for ${conn.contactEmail} — sending CAL.');
      // Start a join timeout.
      conn.joinTimeout?.cancel();
      conn.joinTimeout = Timer(const Duration(seconds: 6), () {
        _log('[AV-SB] JOI timeout for ${conn.contactEmail}.');
        _destroyAvatarSb(conn.contactEmail);
        _markAvatarFetchFailed(
          conn.contactEmail,
          reason: 'avatar SB JOI timeout',
        );
      });
      return;
    }

    if (command == 'JOI' && parts.length > 1) {
      conn.joinTimeout?.cancel();
      conn.joinTimeout = null;
      conn.ready = true;
      _log('[AV-SB] ${conn.contactEmail} JOI — sending avatar INVITE.');
      _sendAvatarInviteOnConn(conn);
      return;
    }

    if (command == 'IRO' && parts.length > 3) {
      conn.joinTimeout?.cancel();
      conn.joinTimeout = null;
      conn.ready = true;
      _log('[AV-SB] ${conn.contactEmail} IRO — sending avatar INVITE.');
      _sendAvatarInviteOnConn(conn);
      return;
    }

    if (command == 'ANS') {
      conn.ready = true;
      return;
    }

    if (command == 'BYE') {
      _log('[AV-SB] BYE on avatar SB for ${conn.contactEmail}.');
      _onAvatarSbDone(conn.contactEmail);
      return;
    }
  }

  /// Sends the display picture INVITE on a dedicated avatar SB connection.
  void _sendAvatarInviteOnConn(_AvatarSbConn conn) {
    final email = conn.contactEmail;
    if (!conn.ready || conn.socket == null) return;
    if (!_avatarInvitePending.contains(email)) return;

    final known = _knownContacts[email];
    final sha1d = (known?.avatarSha1d ?? '').trim();
    final fullMsnObj = (known?.avatarMsnObject ?? '').trim();
    if (sha1d.isEmpty || fullMsnObj.isEmpty) return;

    final dedupeKey = '$email|$sha1d';
    if (_avatarInviteSent.contains(dedupeKey)) return;
    _avatarInviteSent.add(dedupeKey);
    _avatarInvitePending.remove(email);
    _p2pSessionManager.updateStatus(email, 'P2P: Sending INVITE...');

    final inviteResult = _slpService.buildDisplayPictureInviteBinary(
      contactEmail: email,
      myEmail: _email,
      fullMsnObjectXml: fullMsnObj,
    );

    _p2pSessionManager.storeInviteParams(
      peerEmail: email,
      callId: inviteResult.callId,
      branchId: inviteResult.branchId,
      sessionId: inviteResult.sessionId,
      baseId: inviteResult.baseId,
      sha1d: sha1d,
    );

    final mimeHeaders =
        'MIME-Version: 1.0\r\n'
        'Content-Type: application/x-msnmsgrp2p\r\n'
        'P2P-Dest: $email\r\n'
        'P2P-Src: $_email\r\n\r\n';
    final payloadBytes = <int>[
      ...utf8.encode(mimeHeaders),
      ...inviteResult.bytes,
    ];
    conn.sendMsgPayload(payloadBytes, msgFlag: 'D');
    _log('[AV-SB] Sent INVITE for $email sha1d=$sha1d');

    // Start a 15 s timeout waiting for 200 OK.
    conn.responseTimeout?.cancel();
    conn.responseTimeout = Timer(const Duration(seconds: 15), () {
      _log('[AV-SB] 200 OK timeout for $email.');
      _destroyAvatarSb(email);
      _markAvatarFetchFailed(email, reason: 'avatar SB 200 OK timeout');
    });

    // Start a 15 s initial stall timer.
    conn.stallTimer?.cancel();
    conn.stallTimer = Timer(const Duration(seconds: 15), () {
      _log('[AV-SB] Avatar stall timeout for $email (15s no data).');
      _destroyAvatarSb(email);
      _markAvatarFetchFailed(email, reason: 'avatar SB stall timeout');
    });
  }

  /// Handles a P2P MSG payload arriving on a dedicated avatar SB.
  void _handleAvatarSbPayload(
    _AvatarSbConn conn,
    _PendingFrame frame,
    String payload,
    List<int> payloadBytes,
  ) {
    if (frame.command != 'MSG') return;
    final from = conn.contactEmail;

    // Non-P2P payload = regular chat message sent on this avatar SB.
    // Forward it to the event stream so it appears in the chat UI.
    if (!_slpService.isP2pPayloadBytes(payloadBytes)) {
      final event = MsnpParser.parseMsgPayload(
        from: from,
        to: _email,
        payload: payload,
      );
      _eventController.add(event);
      return;
    }

    final frameInfo = _slpService.parseInboundP2pFrame(payloadBytes);
    if (frameInfo == null) return;

    final lowFlags = frameInfo.flags & 0x00FFFFFF;
    final isDataChunk = (lowFlags & 0x20) != 0;
    final isCloseSubStream = (lowFlags & 0x40) != 0 && !isDataChunk;

    // ACK SLP text messages (INVITE, 200 OK, BYE) and data-prep packets.
    final shouldAck = !isDataChunk && (lowFlags == 0x00 || lowFlags == 0x01);
    if (shouldAck && frameInfo.messageSize > 0) {
      final ackBytes = _slpService.buildAckBinary(
        incomingSessionId: frameInfo.sessionId,
        incomingBaseId: frameInfo.baseId,
        ackedTotalSize: frameInfo.totalSize > 0
            ? frameInfo.totalSize
            : frameInfo.messageSize,
      );
      final ackMime =
          'MIME-Version: 1.0\r\n'
          'Content-Type: application/x-msnmsgrp2p\r\n'
          'P2P-Dest: $from\r\n'
          'P2P-Src: $_email\r\n\r\n';
      conn.sendMsgPayload([...utf8.encode(ackMime), ...ackBytes], msgFlag: 'D');
    }

    // ACK close sub-stream.
    if (isCloseSubStream) {
      final ackBytes = _slpService.buildAckBinary(
        incomingSessionId: frameInfo.sessionId,
        incomingBaseId: frameInfo.baseId,
        ackedTotalSize: frameInfo.totalSize,
      );
      final ackMime =
          'MIME-Version: 1.0\r\n'
          'Content-Type: application/x-msnmsgrp2p\r\n'
          'P2P-Dest: $from\r\n'
          'P2P-Src: $_email\r\n\r\n';
      conn.sendMsgPayload([...utf8.encode(ackMime), ...ackBytes], msgFlag: 'D');
    }

    if (lowFlags == 0x02) {
      // Peer ACK'd our INVITE transport packet.
      _p2pSessionManager.updateStatus(
        from,
        'P2P: Peer acknowledged INVITE — waiting for 200 OK',
      );
    }

    if (isDataChunk) {
      final split = _splitP2pBody(payloadBytes);
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
      // Reset stall timer — data is still flowing.
      conn.stallTimer?.cancel();
      conn.stallTimer = Timer(const Duration(seconds: 20), () {
        _log('[AV-SB] Avatar stall for $from — aborting.');
        _p2pSessionManager.closeSession(frameInfo.sessionId);
        _destroyAvatarSb(from);
        _avatarInvitePending.add(from);
        _avatarInviteSent.removeWhere((k) => k.startsWith('$from|'));
        _avatarSilentRequested.removeWhere((k) => k.startsWith('$from|'));
        _tryNextPendingAvatar();
      });

      // Final data-complete ACK.
      if (frameInfo.totalSize > 0 &&
          frameInfo.offset + frameInfo.messageSize >= frameInfo.totalSize) {
        final ackBytes = _slpService.buildAckBinary(
          incomingSessionId: frameInfo.sessionId,
          incomingBaseId: frameInfo.baseId,
          ackedTotalSize: frameInfo.totalSize,
        );
        final ackMime =
            'MIME-Version: 1.0\r\n'
            'Content-Type: application/x-msnmsgrp2p\r\n'
            'P2P-Dest: $from\r\n'
            'P2P-Src: $_email\r\n\r\n';
        conn.sendMsgPayload([
          ...utf8.encode(ackMime),
          ...ackBytes,
        ], msgFlag: 'D');
      }
    } else {
      final slp = frameInfo.slpText;

      if (slp.startsWith('MSNSLP/1.0 ')) {
        final statusLine = slp.split('\r\n').first;
        final statusParts = statusLine.split(' ');
        final statusCode = statusParts.length >= 2
            ? int.tryParse(statusParts[1])
            : null;

        if (statusCode == 200) {
          _avatarBackgroundFailed.remove(from);
          _p2pSessionManager.updateStatus(from, 'P2P: Negotiating session...');
          conn.responseTimeout?.cancel();
          conn.responseTimeout = null;

          final bodySessionId = _extractSlpBodyField(slp, 'SessionID');
          final bodySize =
              _extractSlpBodyField(slp, 'TotalSize') ??
              _extractSlpBodyField(slp, 'DataSize');
          final sessId =
              int.tryParse(bodySessionId ?? '') ?? frameInfo.sessionId;
          final totalSize = int.tryParse(bodySize ?? '') ?? 0;

          // Send SLP-level text ACK.
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
            final ackMime =
                'MIME-Version: 1.0\r\n'
                'Content-Type: application/x-msnmsgrp2p\r\n'
                'P2P-Dest: $from\r\n'
                'P2P-Src: $_email\r\n\r\n';
            conn.sendMsgPayload([
              ...utf8.encode(ackMime),
              ...slpAckBinary,
            ], msgFlag: 'D');
          }

          if (sessId > 0) {
            _p2pSessionManager.openSession(
              sessionId: sessId,
              peerEmail: from,
              totalSize: totalSize,
            );
          }
        } else {
          _destroyAvatarSb(from);
          _markAvatarFetchFailed(from, reason: 'MSNSLP $statusCode response');
        }
      } else if (slp.startsWith('BYE ')) {
        _log('[AV-SB] BYE SLP from $from');
      }
    }
  }

  void _onAvatarSbDone(String email) {
    final norm = email.trim().toLowerCase();
    _log('[AV-SB] Socket closed for $norm.');
    final conn = _avatarSbs[norm];
    if (conn == null) return;

    _destroyAvatarSb(norm);
    _p2pSessionManager.closeAllSessionsForPeer(norm);

    final retries = _avatarSbRetryCount[norm] ?? 0;
    if (retries < 5) {
      _avatarSbRetryCount[norm] = retries + 1;
      _log('[AV-SB] Re-queuing $norm (retry ${retries + 1}/5).');
      _avatarInvitePending.add(norm);
      _avatarInviteSent.removeWhere((k) => k.startsWith('$norm|'));
      _avatarSilentRequested.removeWhere((k) => k.startsWith('$norm|'));
    } else {
      _log('[AV-SB] Max retries for $norm.');
      _markAvatarFetchFailed(norm, reason: 'avatar SB max retries');
    }
    _tryNextPendingAvatar();
  }

  void _onAvatarSbError(String email, Object error) {
    _log('[AV-SB] Socket error for $email: $error');
    _onAvatarSbDone(email);
  }

  /// Tears down a single dedicated avatar SB and removes it from the pool.
  void _destroyAvatarSb(String email) {
    final conn = _avatarSbs.remove(email);
    if (conn != null) {
      // Send OUT so the SB server notifies the peer with BYE.
      conn.send('OUT\r\n');
      conn.destroy();
    }
    _avatarStallTimers[email]?.cancel();
    _avatarStallTimers.remove(email);
  }

  /// Tears down ALL dedicated avatar SBs.
  void _destroyAllAvatarSbs() {
    for (final conn in _avatarSbs.values) {
      conn.send('OUT\r\n');
      conn.destroy();
    }
    _avatarSbs.clear();
    _pendingAvatarXfrs.clear();
    for (final timer in _avatarXfrTimeouts.values) {
      timer.cancel();
    }
    _avatarXfrTimeouts.clear();
    for (final timer in _avatarStallTimers.values) {
      timer.cancel();
    }
    _avatarStallTimers.clear();
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
        _trimLeadingCrlf(_rxBuffer);
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
        _pongTimeout?.cancel();
        _pongTimeout = null;
        _pongMissCount = 0;
        _reconnectAttempts = 0;
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
      case 'OUT':
        _handleServerOut(line);
        break;
      default:
        _handleNumericError(event.command, line);
        break;
    }
  }

  /// Handle an OUT command from the server (forced sign-out).
  /// Reason codes: OTH = signed in elsewhere, SSD = server shutting down.
  void _handleServerOut(String line) {
    final parts = line.trim().split(' ');
    final reason = parts.length > 1 ? parts[1].toUpperCase() : '';
    String message;
    switch (reason) {
      case 'OTH':
        message =
            'You have been signed out because you signed in from another location.';
        break;
      case 'SSD':
        message = 'The server is shutting down. You have been signed out.';
        break;
      default:
        message = 'You have been signed out by the server.';
    }
    _log('Server OUT received: reason=$reason — $message');
    _eventController.add(
      MsnpEvent(
        type: MsnpEventType.system,
        command: 'OUT',
        body: message,
        raw: line,
      ),
    );
    // Do not auto-reconnect for OTH — the other session is intentional.
    if (reason == 'OTH') {
      cancelReconnect();
    }
    _stopKeepAlive();
    _socket?.destroy();
    _socket = null;
    _destroyAllChatSbs();
    _destroyAllAvatarSbs();
    _statusController.add(ConnectionStatus.disconnected);
  }

  /// Handle numeric MSNP error responses (e.g. 217, 280, 911).
  void _handleNumericError(String command, String line) {
    final code = int.tryParse(command);
    if (code == null) return;

    final desc = MsnpErrors.describe(code) ?? 'Unknown error';
    _log('Server error $code: $desc — $line');

    if (MsnpErrors.isAuthError(code)) {
      _eventController.add(
        MsnpEvent(
          type: MsnpEventType.system,
          command: 'ERROR',
          body: 'Authentication failed ($code: $desc)',
          raw: line,
        ),
      );
      cancelReconnect();
      _stopKeepAlive();
      _socket?.destroy();
      _socket = null;
      _statusController.add(ConnectionStatus.error);
    } else if (MsnpErrors.isSwitchboardError(code)) {
      _log('Switchboard error $code — will request new session on next send.');
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

      // ── OIM notification handling ──────────────────────────────────────
      if ((frame.from ?? '').toLowerCase() == 'hotmail' &&
          (payload.contains('text/x-msmsgsinitialmdatanotification') ||
              payload.contains('text/x-msmsgsoimnotification'))) {
        _log('OIM: received notification (${payload.length} chars)');
        _handleOimNotification(payload);
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
    return computeMsnp11Challenge(
      challenge: challenge,
      productId: productId,
      productKey: productKey,
    );
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

  void _onDone() {
    _stopKeepAlive();
    _socket = null;
    _destroyAllChatSbs();
    _destroyAllAvatarSbs();
    _chatSbPendingXfr.clear();
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
    _scheduleReconnect();
  }

  void _onError(Object error, StackTrace stackTrace) {
    _stopKeepAlive();
    _socket = null;
    _destroyAllChatSbs();
    _destroyAllAvatarSbs();
    _chatSbPendingXfr.clear();
    _challengeAckTimer?.cancel();
    _challengeAckTimer = null;
    _log('Socket error: $error');
    _statusController.add(ConnectionStatus.error);
    _scheduleReconnect();
  }

  void _startKeepAlive() {
    _stopKeepAlive();
    _pongMissCount = 0;
    _keepAliveTimer = Timer.periodic(Duration(seconds: _keepAliveSeconds), (_) {
      if (_socket == null) {
        return;
      }
      _send(MsnpCommands.png());
      // If the server doesn't respond within 30 s, count it as a miss.
      // Allow up to _maxPongMisses consecutive misses before disconnecting
      // to tolerate transient Android doze / network hiccups.
      _pongTimeout?.cancel();
      _pongTimeout = Timer(const Duration(seconds: 30), () {
        _pongMissCount++;
        if (_pongMissCount >= _maxPongMisses) {
          _log(
            'QNG pong timeout — $_pongMissCount consecutive misses, forcing disconnect.',
          );
          _stopKeepAlive();
          _socket?.destroy();
          _socket = null;
          _destroyAllChatSbs();
          _destroyAllAvatarSbs();
          _statusController.add(ConnectionStatus.disconnected);
          _scheduleReconnect();
        } else {
          _log(
            'QNG pong timeout — miss $_pongMissCount/$_maxPongMisses, retrying.',
          );
          // Send another ping immediately to probe the connection.
          if (_socket != null) {
            _send(MsnpCommands.png());
          }
        }
      });
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _pongTimeout?.cancel();
    _pongTimeout = null;
  }

  /// Schedules an automatic reconnect with exponential back-off.
  /// Only runs if we have stored credentials from a previous successful connect.
  void _scheduleReconnect() {
    if (_email.isEmpty || _password.isEmpty) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log(
        'Auto-reconnect: max attempts ($_maxReconnectAttempts) reached. Giving up.',
      );
      return;
    }
    if (_reconnectTimer != null) return; // Already scheduled.
    if (_socket != null) return; // Still connected.

    _reconnectAttempts++;
    // Exponential back-off: 3s, 6s, 12s, 24s, 48s … capped at 60s.
    final delaySec = (3 * (1 << (_reconnectAttempts - 1))).clamp(3, 60);
    _log(
      'Auto-reconnect: attempt $_reconnectAttempts/$_maxReconnectAttempts in ${delaySec}s',
    );

    _reconnectTimer = Timer(Duration(seconds: delaySec), () async {
      _reconnectTimer = null;
      if (_socket != null) return; // Connected in the meantime.
      try {
        _log('Auto-reconnect: connecting…');
        await connect(
          email: _email,
          password: _password,
          passportTicket: _passportTicket,
          host: _connectedHost,
          port: _connectedPort,
          isAutoReconnect: true,
        );
      } catch (e) {
        _log('Auto-reconnect failed: $e');
        _scheduleReconnect();
      }
    });
  }

  /// Cancels any pending auto-reconnect timer (e.g. on explicit disconnect or
  /// manual login).
  void cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
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
    required String email,
    required String password,
    required String fallbackTicket,
  }) async {
    final soapTicket = await _requestSoapTicket(
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
    required String email,
    required String password,
  }) async {
    final uri = ServerConfig.authUri();
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
        // Peer went offline — tear down any active SB to this contact
        // since the session is now invalid.
        final normalizedEmail = event.from!.trim().toLowerCase();
        if (_chatSbs.containsKey(normalizedEmail)) {
          _log(
            'Peer $normalizedEmail went offline (FLN) — '
            'tearing down stale SB.',
          );
          _disconnectChatSb(normalizedEmail);
        }
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

    // NOTE: We intentionally do NOT tear down the SB on NLN/ILN presence
    // changes.  A peer going AWY→NLN (background→foreground) does NOT
    // invalidate the SB session — both sides still share the same session.
    // Only FLN (offline) means the peer's SB is truly gone, and that case
    // is handled in _rememberFromEvent().

    // Contact came (back) online — clear any prior avatar-fetch failure so
    // the system retries automatically instead of staying permanently blocked.
    _avatarBackgroundFailed.remove(normalizedEmail);

    final normalizedSha1d = (avatarSha1d ?? '').trim();
    final normalizedMsnObj = (msnObject ?? '').trim();
    if (normalizedEmail.isNotEmpty &&
        normalizedSha1d.isNotEmpty &&
        normalizedMsnObj.isNotEmpty) {
      // Queue P2P MSNObject transfer — the correct MSNP mechanism for
      // fetching contact display pictures.
      _queueAvatarInvite(
        contactEmail: normalizedEmail,
        avatarSha1d: normalizedSha1d,
        fullMsnObjectXml: normalizedMsnObj,
        eagerBackground: true,
      );
    }
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

    // If a chat SB to this contact is already open, piggyback the avatar
    // INVITE on it.
    final chatConn = _chatSbs[normalizedEmail];
    if (chatConn != null && chatConn.ready && chatConn.socket != null) {
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

    // Use the dedicated avatar SB pool for concurrent transfers.
    if (_avatarSbs.containsKey(normalizedEmail))
      return; // already has a session
    _requestAvatarSb(normalizedEmail);
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
    final conn = _chatSbs[normalizedEmail];
    if (conn == null || !conn.ready || conn.socket == null) {
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
    _sendChatSbMsgPayload(normalizedEmail, payloadBytes, debugLabel: mimeHeaders, msgFlag: 'D');
    _log(
      'Queued MSNSLP DP INVITE for $contactEmail sha1d=$avatarSha1d callId=${inviteResult.callId}',
    );
    _avatarSilentRequested.remove(dedupeKey);

    // Lock the per-contact SB for avatar transfer tracking.
    conn.p2pInFlightEmail = normalizedEmail;
    conn.p2pResponseTimeout?.cancel();
    conn.p2pResponseTimeout = Timer(const Duration(seconds: 15), () {
      final c = _chatSbs[normalizedEmail];
      if (c?.p2pInFlightEmail == normalizedEmail) {
        _log('P2P: 200 OK timeout waiting for $normalizedEmail — giving up.');
        _clearChatSbP2pInFlight(normalizedEmail);
        _markAvatarFetchFailed(normalizedEmail, reason: '200 OK timeout');
      }
    });
    // Start a 15-second stall timer that fails the transfer if no data arrives.
    _avatarStallTimers[normalizedEmail]?.cancel();
    _avatarStallTimers[normalizedEmail] = Timer(
      const Duration(seconds: 15),
      () {
        final c = _chatSbs[normalizedEmail];
        if (c?.p2pInFlightEmail == normalizedEmail) {
          _log('P2P: Avatar stall timeout for $normalizedEmail (15s no data).');
          _clearChatSbP2pInFlight(normalizedEmail);
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
      _sendChatSbMsgPayload(
        from,
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
        _sendChatSbMsgPayload(
          from,
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
      _sendChatSbMsgPayload(
        from,
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
      _sendChatSbMsgPayload(
        from,
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
        _sendChatSbMsgPayload(
          from,
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
    _sendChatSbMsgPayload(
      to,
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  OIM (Offline Instant Messaging)
  // ═══════════════════════════════════════════════════════════════════════════

  void _handleOimNotification(String payload) {
    // Extract the mail-data XML from the MSG payload body.
    // The body follows the MIME headers after a blank line.
    var xmlBody = payload;
    final splitIdx = payload.indexOf('\r\n\r\n');
    if (splitIdx != -1) {
      xmlBody = payload.substring(splitIdx + 4);
    } else {
      final nlIdx = payload.indexOf('\n\n');
      if (nlIdx != -1) xmlBody = payload.substring(nlIdx + 2);
    }

    _log(
      'OIM notification XML body (${xmlBody.length} chars): '
      '${xmlBody.length > 500 ? xmlBody.substring(0, 500) : xmlBody}',
    );

    final headers = OimService.parseMailDataNotification(xmlBody);
    if (headers.isEmpty) {
      _log('OIM notification: no pending offline messages.');
      return;
    }

    _log('OIM notification: ${headers.length} pending offline message(s).');
    _retrievePendingOims(headers);
  }

  void _retrievePendingOims(List<OimHeader> headers) {
    _log(
      'OIM _retrievePendingOims: ticket=${_ticket.length} chars, '
      'mspAuth=${(_mspAuth ?? '').length} chars, '
      'sid=${(_sid ?? '').length} chars, '
      'ticketPrefix=${_ticket.length > 10 ? _ticket.substring(0, 10) : _ticket}',
    );
    unawaited(() async {
      final retrieved = <OimMessage>[];
      final idsToDelete = <String>[];

      for (final header in headers) {
        final msg = await OimService.getMessage(
          host: ServerConfig.oimHost,
          ticket: _ticket,
          header: header,
          mspAuth: _mspAuth,
          sid: _sid,
          log: (m) => _log(m),
        );
        if (msg != null) {
          retrieved.add(msg);
          idsToDelete.add(header.messageId);
        }
      }

      // Emit each retrieved OIM as a message event so the chat provider
      // displays them in the conversation thread.
      for (final msg in retrieved) {
        _rememberContact(email: msg.senderEmail, displayName: msg.senderName);
        _eventController.add(
          MsnpEvent(
            type: MsnpEventType.message,
            command: 'OIM',
            from: msg.senderEmail,
            to: _email,
            body: msg.body,
            raw: 'OIM ${msg.senderEmail} ${msg.receivedTime.toIso8601String()}',
          ),
        );
      }

      // Delete retrieved messages from the server.
      if (idsToDelete.isNotEmpty) {
        await OimService.deleteMessages(
          host: ServerConfig.oimHost,
          ticket: _ticket,
          messageIds: idsToDelete,
          mspAuth: _mspAuth,
          log: (m) => _log(m),
        );
      }

      _log('OIM: retrieved ${retrieved.length} offline message(s).');
    }());
  }

  /// Send an offline message to [recipientEmail] via the OIM SOAP service.
  /// Returns true on success.
  Future<bool> sendOfflineMessage({
    required String recipientEmail,
    required String body,
  }) async {
    _log(
      'OIM sendOfflineMessage: ticket=${_ticket.length} chars, '
      'mspAuth=${(_mspAuth ?? '').length} chars, '
      'sid=${(_sid ?? '').length} chars, '
      'ticketPrefix=${_ticket.length > 10 ? _ticket.substring(0, 10) : _ticket}',
    );
    return OimService.sendMessage(
      host: ServerConfig.oimHost,
      ticket: _ticket,
      senderEmail: _email,
      senderName: _selfDisplayName.isNotEmpty ? _selfDisplayName : _email,
      recipientEmail: recipientEmail,
      body: body,
      mspAuth: _mspAuth,
      log: (m) => _log(m),
    );
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
          host: ServerConfig.abchHost,
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

/// Encapsulates a dedicated SB (switchboard) socket for a single avatar P2P
/// transfer.  Multiple instances can run concurrently — one per contact —
/// up to [MsnpClient._maxConcurrentAvatarSbs].
class _AvatarSbConn {
  _AvatarSbConn({required this.contactEmail});

  final String contactEmail;
  Socket? socket;
  final List<int> rxBuffer = <int>[];
  _PendingFrame? pendingFrame;
  bool ready = false;
  bool connecting = false;
  int _trId = 0;
  Timer? joinTimeout;
  Timer? responseTimeout;
  Timer? stallTimer;

  int nextTrId() => ++_trId;

  void send(String command) {
    try {
      socket?.add(utf8.encode(command));
    } catch (_) {}
  }

  void sendMsgPayload(List<int> payloadBytes, {String msgFlag = 'D'}) {
    final cmd = 'MSG ${nextTrId()} $msgFlag ${payloadBytes.length}\r\n';
    try {
      socket?.add(utf8.encode(cmd));
      socket?.add(payloadBytes);
    } catch (_) {}
  }

  void destroy() {
    joinTimeout?.cancel();
    joinTimeout = null;
    responseTimeout?.cancel();
    responseTimeout = null;
    stallTimer?.cancel();
    stallTimer = null;
    try {
      socket?.destroy();
    } catch (_) {}
    socket = null;
    rxBuffer.clear();
    pendingFrame = null;
    ready = false;
    connecting = false;
  }
}

/// Encapsulates a dedicated SB (switchboard) socket for a single chat
/// conversation.  Multiple instances run concurrently — one per contact —
/// stored in [MsnpClient._chatSbs].
class _ChatSbConn {
  _ChatSbConn({required this.contactEmail});

  final String contactEmail;
  Socket? socket;
  final List<int> rxBuffer = <int>[];
  _PendingFrame? pendingFrame;
  bool ready = false;
  bool connecting = false;
  int _trId = 0;

  /// True when we answered an incoming RNG (ANS); false when we initiated (USR).
  bool isInviteMode = false;

  /// Outbound message queue — drained once the SB becomes ready.
  final List<_PendingOutboundMessage> outboundQueue =
      <_PendingOutboundMessage>[];

  /// Tracks MSG flag 'A' messages awaiting ACK/NAK.  Key = SB transaction ID.
  final Map<int, String> pendingAcks = <int, String>{};

  /// Remote participants currently in this SB session (emails, normalised).
  final Set<String> participants = <String>{};

  /// SB server auth credentials (set before connect, cleared on destroy).
  String? sessionId;
  String? authToken;
  String? host;
  int? port;

  /// Timer: 6 s waiting for peer to JOI after CAL.
  Timer? joinTimeout;

  /// Watchdog: fires if we sent texts but received nothing from SB server.
  Timer? sendWatchdog;

  /// Counter of text/nudge messages sent since last server activity.
  int unackedTextSinceRx = 0;

  /// Email of peer whose P2P INVITE we are waiting on (locks this SB for P2P).
  String? p2pInFlightEmail;

  /// 15 s timeout waiting for P2P 200-OK response.
  Timer? p2pResponseTimeout;

  /// Timestamp of last send/receive activity — used for idle eviction.
  DateTime lastActivity = DateTime.now();

  int nextTrId() => ++_trId;

  void send(String command) {
    try {
      socket?.add(utf8.encode(command));
    } catch (_) {}
  }

  int sendMsgPayload(List<int> payloadBytes, {String msgFlag = 'D'}) {
    final trId = nextTrId();
    final cmd = 'MSG $trId $msgFlag ${payloadBytes.length}\r\n';
    try {
      socket?.add(utf8.encode(cmd));
      socket?.add(payloadBytes);
    } catch (_) {}
    return trId;
  }

  void destroy() {
    joinTimeout?.cancel();
    joinTimeout = null;
    sendWatchdog?.cancel();
    sendWatchdog = null;
    p2pResponseTimeout?.cancel();
    p2pResponseTimeout = null;
    try {
      socket?.destroy();
    } catch (_) {}
    socket = null;
    rxBuffer.clear();
    pendingFrame = null;
    ready = false;
    connecting = false;
    isInviteMode = false;
    outboundQueue.clear();
    pendingAcks.clear();
    participants.clear();
    sessionId = null;
    authToken = null;
    host = null;
    port = null;
    p2pInFlightEmail = null;
    unackedTextSinceRx = 0;
  }
}
