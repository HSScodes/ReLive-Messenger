import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wlm_project/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/contact.dart';
import '../../models/message.dart';
import '../../providers/chat_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/p2p_provider.dart';
import '../../services/p2p_session_manager.dart';
import '../../providers/profile_avatar_provider.dart';
import '../../utils/presence_status.dart';
import '../../utils/wlm_color_tags.dart';
import '../../widgets/wlm_scene_background.dart';

class ChatWindowScreen extends ConsumerStatefulWidget {
  const ChatWindowScreen({super.key, required this.contact});

  final Contact contact;

  @override
  ConsumerState<ChatWindowScreen> createState() => _ChatWindowScreenState();
}

class _ChatWindowScreenState extends ConsumerState<ChatWindowScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  Timer? _typingDebounce;
  int _lastThreadSize = 0;

  static const String _assetAvatarFrame =
      'assets/images/extracted/msgsres/carved_png_9812096.png';
  static const String _assetAvatarUser =
      'assets/images/extracted/msgsres/carved_png_9801032.png';
  static const String _assetArrow =
      'assets/images/extracted/msgsres/carved_png_10968848.png';
  static const String _assetIconA =
      'assets/images/extracted/msgsres/carved_png_9663952.png';
  static const String _assetIconB =
      'assets/images/extracted/msgsres/carved_png_9783656.png';
  static const String _assetIconC =
      'assets/images/extracted/msgsres/carved_png_9835392.png';
  static const String _assetIconD =
      'assets/images/extracted/msgsres/carved_png_9727920.png';
  static const String _assetChromeBar =
      'assets/images/extracted/msgsres/carved_png_427616.png';
  static const String _assetChromeBarLight =
      'assets/images/extracted/msgsres/carved_png_433248.png';

  Widget _contactAvatar(Contact contact, {double? width, double? height}) {
    final path = contact.avatarLocalPath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, width: width, height: height, fit: BoxFit.cover);
      }
    }

    return Image.asset(_assetAvatarUser, width: width, height: height, fit: BoxFit.cover);
  }

  Contact _currentContact() {
    final contacts = ref.watch(contactsProvider);
    for (final c in contacts) {
      if (c.email.toLowerCase() == widget.contact.email.toLowerCase()) {
        return c;
      }
    }
    return widget.contact;
  }

  String _statusLabel(BuildContext context, PresenceStatus status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case PresenceStatus.online:
        return l10n.statusOnline;
      case PresenceStatus.busy:
        return l10n.statusBusy;
      case PresenceStatus.away:
        return l10n.statusAway;
      case PresenceStatus.appearOffline:
        return l10n.statusOffline;
    }
  }

  Color _statusFrame(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.online:
        return const Color(0xFF47D84B);
      case PresenceStatus.busy:
        return const Color(0xFFD9554B);
      case PresenceStatus.away:
        return const Color(0xFFE1B54A);
      case PresenceStatus.appearOffline:
        return const Color(0xFF9EACB8);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(msnpClientProvider).requestAvatarFetchForContact(
        widget.contact.email,
        force: true,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollMessagesToBottom());
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _messagesScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _isIncoming(Message message, String contactEmail) {
    return message.from.toLowerCase() == contactEmail.toLowerCase();
  }

  void _scrollMessagesToBottom() {
    if (!_messagesScrollController.hasClients) {
      return;
    }
    _messagesScrollController.jumpTo(_messagesScrollController.position.maxScrollExtent);
  }

  Future<void> _sendMessage(Contact contact) async {
    final body = _controller.text.trim();
    if (body.isEmpty) {
      return;
    }

    await ref.read(chatProvider.notifier).sendMessage(to: contact.email, body: body);
    if (!mounted) {
      return;
    }
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollMessagesToBottom());
  }

  void _sendTypingPulse(Contact contact) {
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 450), () {
      ref.read(chatProvider.notifier).sendTyping(contact.email);
    });
  }

  Future<void> _sendNudge(Contact contact) async {
    await ref.read(chatProvider.notifier).sendNudge(contact.email);
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollMessagesToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final contact = _currentContact();
    ref.watch(chatProvider);
    final selfAvatarPath = ref.watch(profileAvatarProvider);
    final typingContacts = ref.watch(typingContactsProvider);
    final isContactTyping = typingContacts.contains(contact.email.toLowerCase());
    final thread = ref.read(chatProvider.notifier).threadForContact(contact.email);
    if (thread.length != _lastThreadSize) {
      _lastThreadSize = thread.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollMessagesToBottom());
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4AAFE4), Color(0xFFDFE6EE)],
            stops: [0.0, 0.18],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _titleBar(contact),
              _menuBar(),
              _contactHeader(contact),
              // P2P status bar – only shown during active transfers
              Consumer(
                builder: (ctx, cRef, _) {
                  final statusMap =
                      cRef.watch(p2pStatusProvider).asData?.value ?? {};
                  final p2pSt = statusMap[contact.email.toLowerCase()];
                  if (p2pSt == null || p2pSt.message.isEmpty || p2pSt.message == 'Avatar: idle') {
                    return const SizedBox.shrink();
                  }
                  return _p2pStatusBar(p2pSt);
                },
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.80),
                    border: Border.all(color: const Color(0xFF94B2CB)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3A7DB8).withOpacity(0.08),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFB4C7D7)),
                          ),
                          child: ListView.builder(
                            controller: _messagesScrollController,
                            padding: const EdgeInsets.all(10),
                            itemCount: thread.length,
                            itemBuilder: (context, index) {
                              final message = thread[index];
                              final incoming = _isIncoming(message, contact.email);
                              return Align(
                                alignment: incoming ? Alignment.centerLeft : Alignment.centerRight,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: incoming
                                        ? const Color(0xFFE5F3FD)
                                        : const Color(0xFFDFF5E0),
                                    border: Border.all(color: const Color(0xFFAAC0D3)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        incoming
                                            ? l10n.messageSays(stripWlmColorTags(contact.displayName))
                                            : l10n.messageMeSays,
                                        style: const TextStyle(
                                          color: Color(0xFF26445E),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        message.body,
                                        style: TextStyle(
                                          color: message.isNudge
                                              ? const Color(0xFFB02222)
                                              : const Color(0xFF1B3146),
                                          fontSize: 14,
                                          fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'Arial'],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (isContactTyping)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCEAF6),
                            border: Border.all(color: const Color(0xFFB2C7D9)),
                          ),
                          child: Text(
                            l10n.typingIndicator(stripWlmColorTags(contact.displayName)),
                            style: const TextStyle(
                              color: Color(0xFF375A78),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
                            ),
                          ),
                        ),
                      _composeArea(contact,
                          selfAvatarPath: selfAvatarPath,
                          selfStatus: ref.read(msnpClientProvider).selfPresence),
                    ],
                  ),
                ),
              ),
              _footerStatus(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleBar(Contact contact) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage(_assetChromeBar),
          fit: BoxFit.fill,
          colorFilter: ColorFilter.mode(
            const Color(0xFF1A4A7A).withValues(alpha: 0.3),
            BlendMode.darken,
          ),
        ),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E4E82), Color(0xFF2C79B4)],
        ),
      ),
      child: Row(
        children: [
          Image.asset(_assetIconC, width: 16, height: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${stripWlmColorTags(contact.displayName)} <${contact.email}>',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
              ),
            ),
          ),
          _captionButton('−'),
          _captionButton('□'),
          _captionButton('×', close: true),
        ],
      ),
    );
  }

  Widget _menuBar() {
    const entries = ['Photos', 'Files', 'Video', 'Call', 'Games'];
    return Container(
      height: 30,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage(_assetChromeBarLight),
          fit: BoxFit.fill,
          colorFilter: ColorFilter.mode(
            const Color(0xFF8AB8D8).withValues(alpha: 0.12),
            BlendMode.srcATop,
          ),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFBEDAEF),
            Color(0xFFA5CAE4),
            Color(0xFF88B8D8),
            Color(0xFF75A8CE),
          ],
          stops: [0.0, 0.35, 0.5, 1.0],
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFB9D9EE),
                  border: Border.all(color: const Color(0xFF7BA4C1)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Transform.rotate(
                  angle: math.pi,
                  child: Image.asset(_assetArrow, width: 13, height: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(
                  e,
                  style: const TextStyle(
                    color: Color(0xFF153B5D),
                    fontSize: 15,
                    fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
                  ),
                ),
              ),
            Image.asset(_assetIconD, width: 16, height: 16),
            const SizedBox(width: 8),
            Image.asset(_assetIconA, width: 16, height: 16),
            const SizedBox(width: 8),
            Image.asset(_assetArrow, width: 13, height: 12),
          ],
        ),
      ),
    );
  }

  Widget _p2pStatusBar(P2pStatus status) {
    final isComplete = status.message.contains('Complete');
    final isIdle = status.message == 'Avatar: idle';
    final bgColor = isIdle
        ? Colors.amber.shade100
        : isComplete
            ? const Color(0xFFD9EDD9)
            : Colors.amber.shade300;
    final borderColor = isIdle
        ? Colors.amber.shade400
        : isComplete
            ? const Color(0xFF7DB87D)
            : Colors.amber.shade700;
    final textColor = isComplete
        ? const Color(0xFF1A7A1A)
        : const Color(0xFF4A3A00);
    final showProgress =
        status.totalSize > 0 && status.bytesReceived > 0 && !isComplete;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.message,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Segoe UI',
              fontFamilyFallback: const ['Tahoma', 'Arial'],
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: status.progress,
              backgroundColor: Colors.amber.shade100,
              color: Colors.amber.shade700,
              minHeight: 5,
            ),
          ],
        ],
      ),
    );
  }

  /// Returns a gradient background widget for the contact header.
  /// Uses the contact's colorScheme from UBX when available,
  /// and falls back to the default WLM blue-sky scene as base.
  Widget _sceneBackground(Contact contact) {
    // Try to use the contact's UBX <ColorScheme> first.
    // "-1" is the WLM default meaning "no custom colour — use default scene".
    final cs = contact.colorScheme;
    if (cs != null && cs.isNotEmpty && cs != '-1') {
      final parsed = int.tryParse(cs);
      if (parsed != null && parsed != 0) {
        // WLM stores as negative 24-bit RGB packed int.
        final rgb = parsed < 0 ? (0xFFFFFF + parsed + 1) : parsed;
        return _colorGradientScene(Color(0xFF000000 | (rgb & 0xFFFFFF)));
      }
    }

    // Default: WLM 2009 blue-sky scene with light rays.
    return const WlmSceneBackground(height: 130);
  }

  Widget _colorGradientScene(Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);
    final lighter = hsl.withLightness((hsl.lightness + 0.25).clamp(0.0, 0.95)).toColor();
    final lightest = hsl.withLightness((hsl.lightness + 0.45).clamp(0.0, 0.97)).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [baseColor, lighter, lightest],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }

  /// Builds a list of [TextSpan]s from a WLM display name, respecting
  /// `[c=N]` colour tags.
  List<InlineSpan> _buildColoredName(
    String raw, {
    required Color defaultColor,
    required double fontSize,
  }) {
    final segments = parseWlmColorTags(raw, defaultColor: defaultColor);
    return segments
        .map(
          (s) => TextSpan(
            text: s.text,
            style: TextStyle(
              color: s.color,
              fontSize: fontSize,
              fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'Arial'],
              shadows: const [
                Shadow(color: Colors.white, blurRadius: 4),
              ],
            ),
          ),
        )
        .toList();
  }

  Widget _contactHeader(Contact contact) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF7FAECE), width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: [
          // Scene background – driven by contact's UBX data
          Positioned.fill(
            child: _sceneBackground(contact),
          ),
          // Soft vignette overlay so text is readable
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ),
          // Contact info overlay
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 68,
                  height: 68,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Photo / placeholder behind the Aero frame
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _contactAvatar(contact, width: 56, height: 56),
                      ),
                      // Aero glass frame, recolored by status
                      Positioned.fill(
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            _statusFrame(contact.status).withValues(alpha: 0.72),
                            BlendMode.srcATop,
                          ),
                          child: Image.asset(_assetAvatarFrame,
                              fit: BoxFit.fill),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: _buildColoredName(
                            contact.displayName,
                            defaultColor: const Color(0xFFD61C1C),
                            fontSize: 20,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '(${_statusLabel(context, contact.status)})',
                        style: TextStyle(
                          color: const Color(0xFF1F1F1F),
                          fontSize: 14,
                          fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'Arial'],
                          shadows: [
                            Shadow(
                              color: Colors.white.withValues(alpha: 0.8),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                  contact.nowPlaying != null && contact.nowPlaying!.isNotEmpty
                      ? '♫ ${contact.nowPlaying}'
                      : (contact.personalMessage != null && contact.personalMessage!.isNotEmpty
                          ? contact.personalMessage!
                          : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF1C4E78),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'Arial'],
                        shadows: [
                          Shadow(
                            color: Colors.white.withValues(alpha: 0.8),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ],
      ),
    );
  }

  Widget _composeArea(Contact contact,
      {required String? selfAvatarPath,
      PresenceStatus selfStatus = PresenceStatus.online}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Self avatar column
          Padding(
            padding: const EdgeInsets.only(bottom: 4, right: 4),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _statusFrame(selfStatus),
                          width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: _statusFrame(selfStatus).withOpacity(0.40),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                  Image.asset(_assetAvatarFrame, width: 50, height: 50),
                  _selfAvatar(selfAvatarPath, width: 36, height: 36),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                // Text field
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EEF5),
                    border: Border.all(color: const Color(0xFFAFBECF)),
                  ),
                  child: TextField(
                    controller: _controller,
                    onChanged: (_) => _sendTypingPulse(contact),
                    onSubmitted: (_) => _sendMessage(contact),
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(8),
                    ),
                  ),
                ),
                // Toolbar row
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFEDF3F8), Color(0xFFD9E4EE)],
                    ),
                    border: Border.all(color: const Color(0xFFB3C4D3)),
                  ),
                  child: Row(
                    children: [
                      Image.asset(_assetIconD, width: 16, height: 16),
                      const SizedBox(width: 8),
                      Image.asset(_assetIconC, width: 16, height: 16),
                      const SizedBox(width: 8),
                      Image.asset(_assetIconA, width: 16, height: 16),
                      const SizedBox(width: 8),
                      Image.asset(_assetIconB, width: 16, height: 16),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _sendNudge(contact),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFE5ECF3), Color(0xFFCDD9E6)],
                            ),
                            border: Border.all(color: const Color(0xFF96ADC1)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('Nudge',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E4F82),
                                  fontFamilyFallback: [
                                    'Segoe UI',
                                    'Tahoma'
                                  ])),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _sendMessage(contact),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF5A9AD0), Color(0xFF3678B0)],
                            ),
                            border: Border.all(color: const Color(0xFF1E4F82)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('Send',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontFamilyFallback: [
                                    'Segoe UI',
                                    'Tahoma'
                                  ])),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F0F6), Color(0xFFD5E2ED)],
        ),
        border: const Border(top: BorderSide(color: Color(0xFFAAC5DB))),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            offset: const Offset(0, -1),
            blurRadius: 0,
          ),
        ],
      ),
      child: const Text(
        'SpaceHey - a space for friends.',
        style: TextStyle(
          color: Color(0xFF223548),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
        ),
      ),
    );
  }

  Widget _captionButton(String text, {bool close = false}) {
    return Container(
      width: 28,
      height: 20,
      margin: const EdgeInsets.only(left: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: close
              ? [const Color(0xFFDA6B4F), const Color(0xFFC3473A)]
              : [const Color(0xFF5899CC), const Color(0xFF3D78A9)],
        ),
        border: Border.all(color: const Color(0x80FFFFFF)),
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          shadows: [Shadow(color: Color(0x60000000), blurRadius: 2)],
        ),
      ),
    );
  }

  Widget _selfAvatar(String? path, {double? width, double? height}) {
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, width: width, height: height, fit: BoxFit.cover);
      }
    }

    return Image.asset(_assetAvatarUser, width: width, height: height, fit: BoxFit.cover);
  }
}
