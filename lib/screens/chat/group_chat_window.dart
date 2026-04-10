import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:wlm_project/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/contact.dart';
import '../../models/message.dart';
import '../../models/group_conversation.dart';
import '../../network/msnp_client.dart';
import '../../network/msnp_parser.dart';
import '../../providers/chat_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/group_conversations_provider.dart';
import '../../providers/profile_avatar_provider.dart';
import '../../utils/presence_status.dart';
import '../../utils/wlm_color_tags.dart';
import '../../widgets/win7_back_button.dart';
import '../../widgets/emoticon_text.dart';
import '../../widgets/emoticon_picker.dart';
import 'chat_window.dart';

/// Dedicated group chat window. Displays a multi-participant header with
/// aero-framed avatars for every participant, a Leave button, and a clean
/// thread that only shows messages for this group conversation.
class GroupChatWindowScreen extends ConsumerStatefulWidget {
  const GroupChatWindowScreen({super.key, required this.group});

  final GroupConversation group;

  @override
  ConsumerState<GroupChatWindowScreen> createState() =>
      _GroupChatWindowScreenState();
}

class _GroupChatWindowScreenState extends ConsumerState<GroupChatWindowScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  Timer? _typingDebounce;
  int _lastThreadSize = 0;
  OverlayEntry? _emoticonOverlay;
  bool _nudgeCooldown = false;

  // Nudge shake animation
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  static const String _assetAvatarFrame =
      'assets/images/app/ui/carved_png_9812096.png';
  static const String _assetAvatarUser =
      'assets/images/usertiles/new_default.png';
  static const String _assetNudgeIcon =
      'assets/images/app/ui/carved_png_9432408.png';

  StreamSubscription<MsnpEvent>? _eventSub;

  Widget _contactAvatar(Contact contact, {double? width, double? height}) {
    final path = contact.ddpLocalPath ?? contact.avatarLocalPath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            _assetAvatarUser,
            width: width,
            height: height,
            fit: BoxFit.cover,
          ),
        );
      }
    }
    return Image.asset(
      _assetAvatarUser,
      width: width,
      height: height,
      fit: BoxFit.cover,
    );
  }

  Color _statusFrame(PresenceStatus status) {
    switch (status) {
      case PresenceStatus.online:
        return const Color(0xFF39FF14);
      case PresenceStatus.busy:
        return const Color(0xFFD9554B);
      case PresenceStatus.away:
        return const Color(0xFFE1B54A);
      case PresenceStatus.appearOffline:
        return const Color(0xFF9EACB8);
    }
  }

  /// Resolve a Contact from the contacts list by email.
  Contact? _resolveContact(String email) {
    final contacts = ref.read(contactsProvider);
    for (final c in contacts) {
      if (c.email.toLowerCase() == email.toLowerCase()) return c;
    }
    return null;
  }

  /// Resolve display name for an email.
  String _resolveDisplayName(String email) {
    final c = _resolveContact(email);
    if (c != null) {
      final n = stripWlmColorTags(c.displayName);
      if (n.isNotEmpty && n != c.email) return n;
    }
    return email;
  }

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollMessagesToBottom(),
    );

    // Listen for SBLEAVE events — when group drops to 1 remote participant,
    // auto-revert to that contact's 1:1 chat window.
    final client = ref.read(msnpClientProvider);
    _eventSub = client.events.listen((event) {
      if (!mounted) return;
      if (event.type == MsnpEventType.system && event.command == 'SBLEAVE') {
        _checkAutoRevert();
      }
    });
  }

  void _checkAutoRevert() {
    final client = ref.read(msnpClientProvider);
    final sbKey = client.sbKeyForGroup(widget.group.participants);
    final participants = sbKey != null ? client.sbParticipants(sbKey) : <String>{};
    // If there's only 1 remote participant left, the group has ended.
    if (participants.length <= 1 && participants.isNotEmpty) {
      final remainingEmail = participants.first;
      final contact = _resolveContact(remainingEmail);
      if (contact != null && mounted) {
        // Remove the group conversation entry.
        ref.read(groupConversationsProvider.notifier).remove(widget.group.id);
        // Replace this group window with the 1:1 chat window.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ChatWindowScreen(contact: contact)),
        );
      }
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _emoticonOverlay?.remove();
    _typingDebounce?.cancel();
    _shakeController.dispose();
    _messagesScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<Message> _buildThread() {
    final chatNotifier = ref.read(chatProvider.notifier);
    return chatNotifier.threadForGroup(widget.group.id);
  }

  bool _isIncoming(Message message) {
    final selfEmail = ref.read(msnpClientProvider).selfEmail.toLowerCase();
    if (selfEmail.isNotEmpty) {
      return message.from.toLowerCase() != selfEmail;
    }
    return true;
  }

  void _scrollMessagesToBottom() {
    if (!_messagesScrollController.hasClients) return;
    _messagesScrollController.jumpTo(
      _messagesScrollController.position.maxScrollExtent,
    );
  }

  Future<void> _sendMessage() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    // Send to any participant in the group; the SB session will broadcast.
    final targetEmail = widget.group.participants.first;
    await ref
        .read(chatProvider.notifier)
        .sendMessage(
          to: targetEmail,
          body: body,
          conversationId: widget.group.id,
        );
    if (!mounted) return;
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollMessagesToBottom(),
    );
  }

  void _sendTypingPulse() {
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 450), () {
      final targetEmail = widget.group.participants.first;
      ref.read(chatProvider.notifier).sendTyping(targetEmail);
    });
  }

  Future<void> _sendNudge() async {
    if (_nudgeCooldown) return;
    _nudgeCooldown = true;
    final targetEmail = widget.group.participants.first;
    await ref.read(chatProvider.notifier).sendNudge(targetEmail);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollMessagesToBottom(),
    );
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _nudgeCooldown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.watch(chatProvider);
    final selfAvatarPath = ref.watch(profileAvatarProvider);
    final thread = _buildThread();

    if (thread.length != _lastThreadSize) {
      if (thread.length > _lastThreadSize && thread.isNotEmpty) {
        final newest = thread.last;
        if (newest.isNudge && _isIncoming(newest)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _shakeController.forward(from: 0);
          });
        }
      }
      _lastThreadSize = thread.length;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollMessagesToBottom(),
      );
    }

    // Resolve current participants from the live SB session if available,
    // fall back to the group model's participant list.
    final client = ref.watch(msnpClientProvider);
    final sbKey = client.sbKeyForGroup(widget.group.participants);
    final liveParticipants = (sbKey != null && client.isGroupSession(sbKey))
        ? client.sbParticipants(sbKey)
        : widget.group.participants;

    // Build the display label
    final names = liveParticipants.map((e) => _resolveDisplayName(e)).toList();
    final label = names.join(', ');

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final dx = _shakeController.isAnimating
            ? sin(_shakeAnimation.value * pi * 6) * 8.0
            : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF4AAFE4),
                Color(0xFF7CC8F0),
                Color(0xFFB8DDF4),
                Color(0xFFDAEDF8),
                Color(0xFFE8F2FA),
              ],
              stops: [0.0, 0.10, 0.25, 0.40, 0.60],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _titleBar(label),
                _menuBar(),
                _groupContactHeader(liveParticipants),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.68),
                                const Color(0xFFE8F0F8).withOpacity(0.72),
                                const Color(0xFFDEEAF4).withOpacity(0.78),
                                const Color(0xFFD8E6F0).withOpacity(0.82),
                              ],
                              stops: const [0.0, 0.2, 0.6, 1.0],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.55),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF1A4978,
                                ).withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withOpacity(0.50),
                                        const Color(
                                          0xFFF0F5FA,
                                        ).withOpacity(0.55),
                                        const Color(
                                          0xFFE8EFF6,
                                        ).withOpacity(0.60),
                                      ],
                                      stops: const [0.0, 0.4, 1.0],
                                    ),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFCBDAE8,
                                      ).withOpacity(0.50),
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.3),
                                        blurRadius: 1,
                                        spreadRadius: -1,
                                        offset: const Offset(0, -1),
                                      ),
                                    ],
                                  ),
                                  child: ListView.builder(
                                    controller: _messagesScrollController,
                                    padding: const EdgeInsets.all(10),
                                    itemCount: thread.length,
                                    itemBuilder: (context, index) {
                                      final message = thread[index];

                                      // System messages (join / leave)
                                      if (message.from == 'system') {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Center(
                                            child: Text(
                                              message.body,
                                              style: const TextStyle(
                                                color: Color(0xFF5A7A94),
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                                fontFamilyFallback: [
                                                  'Segoe UI',
                                                  'Tahoma',
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      final incoming = _isIncoming(message);
                                      final showHeader =
                                          index == 0 ||
                                          thread[index - 1].from !=
                                              message.from;

                                      final String? senderName;
                                      if (incoming) {
                                        senderName = _resolveDisplayName(
                                          message.from,
                                        );
                                      } else {
                                        senderName = null;
                                      }
                                      final selfName = ref
                                          .read(msnpClientProvider)
                                          .selfDisplayName;

                                      return Padding(
                                        padding: EdgeInsets.only(
                                          top: showHeader && index > 0 ? 8 : 0,
                                          bottom: 1,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (showHeader)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 2,
                                                ),
                                                child: Text(
                                                  incoming
                                                      ? l10n.messageSays(
                                                          senderName!,
                                                        )
                                                      : l10n.messageMeSays(
                                                          selfName,
                                                        ),
                                                  style: TextStyle(
                                                    color: incoming
                                                        ? const Color(
                                                            0xFF2A6A9E,
                                                          )
                                                        : const Color(
                                                            0xFF2A7A3A,
                                                          ),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    fontFamilyFallback: const [
                                                      'Segoe UI',
                                                      'Tahoma',
                                                      'Arial',
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 14,
                                              ),
                                              child: Text.rich(
                                                TextSpan(
                                                  children: [
                                                    const TextSpan(
                                                      text: '■ ',
                                                      style: TextStyle(
                                                        fontSize: 7,
                                                        color: Color(
                                                          0xFF8AAEC4,
                                                        ),
                                                      ),
                                                    ),
                                                    buildEmoticonSpan(
                                                      message.body,
                                                      TextStyle(
                                                        color: message.isNudge
                                                            ? const Color(
                                                                0xFFB85030,
                                                              )
                                                            : const Color(
                                                                0xFF2A3E50,
                                                              ),
                                                        fontSize: 13.5,
                                                        height: 1.4,
                                                        fontFamilyFallback:
                                                            const [
                                                              'Segoe UI',
                                                              'Tahoma',
                                                              'Arial',
                                                            ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              _composeArea(selfAvatarPath: selfAvatarPath),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleBar(String label) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3B9AD9), Color(0xFF2D7DBF), Color(0xFF2570AC)],
          stops: [0.0, 0.5, 1.0],
        ),
        border: Border(
          top: BorderSide(color: Color(0x55FFFFFF), width: 1),
          bottom: BorderSide(color: Color(0x18000000), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/app/app_logo_24.png',
            width: 18,
            height: 18,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'Arial'],
                shadows: const [
                  Shadow(color: Color(0x33000000), blurRadius: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuBar() {
    return Container(
      height: 34,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5AB0E2), Color(0xFF72C0EC), Color(0xFF5AAEE0)],
          stops: [0.0, 0.4, 1.0],
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.20), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Win7BackButton(
            size: 26,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 16,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.0),
                  Colors.white.withOpacity(0.35),
                  Colors.white.withOpacity(0.0),
                ],
              ),
            ),
          ),
          // Leave button — group-only action
          GestureDetector(
            onTap: () async {
              final client = ref.read(msnpClientProvider);
              final sbKey = client.sbKeyForGroup(widget.group.participants);
              if (sbKey != null) {
                await client.leaveSwitchboard(sbKey);
              }
              if (mounted) Navigator.of(context).pop();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'Leave',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'Arial'],
                  shadows: const [
                    Shadow(color: Color(0x22000000), blurRadius: 3),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the multi-participant header with aero-framed avatars side by side.
  Widget _groupContactHeader(Set<String> participants) {
    final contacts = ref.watch(contactsProvider);
    final resolved = <Contact>[];
    for (final email in participants) {
      Contact? found;
      for (final c in contacts) {
        if (c.email.toLowerCase() == email.toLowerCase()) {
          found = c;
          break;
        }
      }
      if (found != null) {
        resolved.add(found);
      } else {
        // Fallback: Create a minimal display contact
        resolved.add(
          Contact(
            email: email,
            displayName: email,
            status: PresenceStatus.appearOffline,
          ),
        );
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.72),
            const Color(0xFFE8F0F8).withOpacity(0.78),
            const Color(0xFFDCE8F2).withOpacity(0.82),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.65), width: 1.2),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A4978).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            blurRadius: 1,
            spreadRadius: -1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle top glass highlight
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.55),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                // Aero-framed avatars side by side
                ...resolved.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 6,
                            left: 6,
                            right: 6,
                            bottom: 6,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: _contactAvatar(c, width: 48, height: 48),
                            ),
                          ),
                          Positioned.fill(
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                _statusFrame(c.status).withValues(alpha: 0.35),
                                BlendMode.srcATop,
                              ),
                              child: Image.asset(
                                _assetAvatarFrame,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        resolved
                            .map((c) => stripWlmColorTags(c.displayName))
                            .join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1A3A5C),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
                          shadows: [Shadow(color: Colors.white, blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${resolved.length} participants',
                        style: const TextStyle(
                          color: Color(0xFF5A7A94),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
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

  Widget _composeArea({required String? selfAvatarPath}) {
    final selfStatus = ref.read(msnpClientProvider).selfPresence;
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Self avatar at bottom-left
              Padding(
                padding: const EdgeInsets.only(right: 0, bottom: 2),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 4,
                        left: 4,
                        right: 4,
                        bottom: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: _selfAvatar(
                            selfAvatarPath,
                            width: 42,
                            height: 42,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            _statusFrame(selfStatus).withValues(alpha: 0.35),
                            BlendMode.srcATop,
                          ),
                          child: Image.asset(
                            _assetAvatarFrame,
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Triangle tail
              Transform.translate(
                offset: const Offset(4, 0),
                child: CustomPaint(
                  size: const Size(14, 26),
                  painter: _BalloonTailPainter(
                    fillColor: const Color(0xFFF0F5FB),
                    borderColor: const Color(0xFFBDD4E6),
                  ),
                ),
              ),
              // Composer balloon
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFBDD4E6).withOpacity(0.65),
                      width: 1,
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.12, 0.5, 1.0],
                      colors: [
                        Color(0xFFF6FAFF),
                        Color(0xFFF0F5FB),
                        Color(0xFFEAF1F8),
                        Color(0xFFE2ECF5),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A7A9C).withOpacity(0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.50),
                        blurRadius: 1,
                        spreadRadius: -1,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 2,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(9),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.60),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                        child: SizedBox(
                          height: 52,
                          child: TextField(
                            controller: _controller,
                            onChanged: (_) => _sendTypingPulse(),
                            onSubmitted: (_) => _sendMessage(),
                            maxLines: null,
                            expands: true,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF2A3E50),
                              fontFamilyFallback: [
                                'Segoe UI',
                                'Tahoma',
                                'Arial',
                              ],
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(
                                color: Color(0xFFA0B8CC),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                fontFamilyFallback: [
                                  'Segoe UI',
                                  'Tahoma',
                                  'Arial',
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                        child: Row(
                          children: [
                            _emoticonButton(),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _sendNudge(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFF0A84C),
                                      Color(0xFFDE8A28),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFCC7818,
                                    ).withOpacity(0.50),
                                    width: 0.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFCC7818,
                                      ).withOpacity(0.18),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      _assetNudgeIcon,
                                      width: 15,
                                      height: 15,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Nudge',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontFamilyFallback: [
                                          'Segoe UI',
                                          'Tahoma',
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _sendMessage(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF6CB8E0),
                                      Color(0xFF4A9BD4),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF3A82B8,
                                    ).withOpacity(0.50),
                                    width: 0.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF2A6A9E,
                                      ).withOpacity(0.18),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'Send',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selfAvatar(String? path, {double? width, double? height}) {
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            _assetAvatarUser,
            width: width,
            height: height,
            fit: BoxFit.cover,
          ),
        );
      }
    }
    return Image.asset(
      _assetAvatarUser,
      width: width,
      height: height,
      fit: BoxFit.cover,
    );
  }

  // ── Emoticon picker ──────────────────────────────────────────────────

  final GlobalKey _emoticonBtnKey = GlobalKey();

  Widget _emoticonButton() {
    return GestureDetector(
      key: _emoticonBtnKey,
      onTap: _toggleEmoticonPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: SizedBox(
          width: 19,
          height: 19,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: 1520,
              maxHeight: 19,
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/images/app/ui/carved_png_9495208.png',
                width: 1520,
                height: 19,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleEmoticonPicker() {
    if (_emoticonOverlay != null) {
      _emoticonOverlay!.remove();
      _emoticonOverlay = null;
      return;
    }
    final renderBox =
        _emoticonBtnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);

    _emoticonOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeEmoticonPicker,
            ),
          ),
          Positioned(
            left: offset.dx,
            bottom: MediaQuery.of(context).size.height - offset.dy + 4,
            child: EmoticonPicker(
              onPicked: (code) {
                final sel = _controller.selection;
                final text = _controller.text;
                final newText =
                    text.substring(0, sel.baseOffset) +
                    code +
                    text.substring(sel.extentOffset);
                _controller.value = TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(
                    offset: sel.baseOffset + code.length,
                  ),
                );
                _closeEmoticonPicker();
              },
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_emoticonOverlay!);
  }

  void _closeEmoticonPicker() {
    _emoticonOverlay?.remove();
    _emoticonOverlay = null;
  }
}

class _BalloonTailPainter extends CustomPainter {
  _BalloonTailPainter({required this.fillColor, required this.borderColor});
  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeJoin = StrokeJoin.round;
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width - 3, size.height));
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height * 0.5)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, fill);
    final borderPath = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height * 0.5)
      ..lineTo(size.width, size.height);
    canvas.drawPath(borderPath, border);
  }

  @override
  bool shouldRepaint(_BalloonTailPainter old) =>
      old.fillColor != fillColor || old.borderColor != borderColor;
}
