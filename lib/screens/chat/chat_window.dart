import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
import '../../widgets/win7_back_button.dart';
import '../../widgets/wlm_scene_background.dart';
import '../../widgets/emoticon_text.dart';
import '../../widgets/emoticon_picker.dart';
import '../../widgets/avatar_widget.dart';

class ChatWindowScreen extends ConsumerStatefulWidget {
  const ChatWindowScreen({super.key, required this.contact});

  final Contact contact;

  @override
  ConsumerState<ChatWindowScreen> createState() => _ChatWindowScreenState();
}

class _ChatWindowScreenState extends ConsumerState<ChatWindowScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  Timer? _typingDebounce;
  int _lastThreadSize = 0;
  OverlayEntry? _emoticonOverlay;

  // Nudge shake animation
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  static const String _assetAvatarFrame =
      'assets/images/extracted/msgsres/carved_png_9812096.png';
  static const String _assetAvatarUser =
      'assets/images/extracted/msgsres/carved_png_9801032.png';
  static const String _assetWlmIcon =
      'assets/images/extracted/msgsres/carved_png_9835392.png';
    static const String _assetNudgeIcon =
      'assets/images/extracted/msgsres/carved_png_9432408.png';

  static const String _assetChromeBar =
      'assets/images/extracted/msgsres/carved_png_427616.png';
  static const String _assetChromeBarLight =
      'assets/images/extracted/msgsres/carved_png_433248.png';

  Widget _contactAvatar(Contact contact, {double? width, double? height}) {
    // Prefer DDP (dynamic display picture / animated GIF) over static avatar.
    final path = contact.ddpLocalPath ?? contact.avatarLocalPath;
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
        return const Color(0xFF39FF14);
      case PresenceStatus.busy:
        return const Color(0xFFD9554B);
      case PresenceStatus.away:
        return const Color(0xFFE1B54A);
      case PresenceStatus.appearOffline:
        return const Color(0xFF9EACB8);
    }
  }

  Color _contactThemeBase(Contact contact) {
    final cs = contact.colorScheme;
    if (cs != null && cs.isNotEmpty && cs != '-1') {
      final parsed = int.tryParse(cs);
      if (parsed != null && parsed != 0) {
        final rgb = parsed < 0 ? (0xFFFFFF + parsed + 1) : parsed;
        return Color(0xFF000000 | (rgb & 0xFFFFFF));
      }
    }
    return const Color(0xFF2C79B4);
  }

  Color _lighten(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + delta).clamp(0.0, 1.0))
        .toColor();
  }

  Color _darken(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - delta).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.linear),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only trigger a P2P fetch if the contact doesn't already have a
      // cached avatar.  Using force:true on every chat open causes a new
      // SB + INVITE cycle that, on timeout, wipes the existing avatar.
      final hasAvatar = widget.contact.avatarLocalPath != null &&
          widget.contact.avatarLocalPath!.isNotEmpty;
      if (!hasAvatar) {
        ref.read(msnpClientProvider).requestAvatarFetchForContact(
          widget.contact.email,
          force: true,
        );
      }
      // Refresh cached avatar (CrossTalk / persistent cache) for this contact.
      ref.read(contactsProvider.notifier).refreshAvatarFor(widget.contact.email);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollMessagesToBottom());
  }

  @override
  void dispose() {
    _emoticonOverlay?.remove();
    _typingDebounce?.cancel();
    _shakeController.dispose();
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

  Future<void> _pickAndSendFile(Contact contact) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    await ref.read(chatProvider.notifier).sendFile(
      to: contact.email,
      filePath: file.path!,
    );
    if (mounted) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollMessagesToBottom());
    }
  }

  void _showInviteContactPicker(Contact currentContact) {
    final contacts = ref.read(contactsProvider);
    final online = contacts
        .where((c) =>
            c.status != PresenceStatus.appearOffline &&
            c.email.toLowerCase() != currentContact.email.toLowerCase())
        .toList();

    if (online.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other contacts online to invite.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFFF0F4F8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: Color(0xFF7A9BB5)),
          ),
          child: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2B6DAD), Color(0xFF4A9BD9)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Invite Contact',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: online.length,
                    itemBuilder: (_, i) {
                      final c = online[i];
                      return ListTile(
                        dense: true,
                        leading: AvatarWidget(
                          status: c.status,
                          imagePath: c.ddpLocalPath ?? c.avatarLocalPath,
                          size: 32,
                        ),
                        title: Text(
                          stripWlmColorTags(c.displayName),
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                          ),
                        ),
                        subtitle: Text(c.email,
                            style: const TextStyle(fontSize: 11)),
                        onTap: () {
                          Navigator.pop(ctx);
                          // CAL the contact into the existing switchboard
                          ref.read(msnpClientProvider).inviteToSwitchboard(c.email);
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel',
                          style: TextStyle(color: Color(0xFF4A6A84))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fileTransferBubble(
      Message message, bool incoming, Contact contact) {
    final state = message.fileTransferState;
    final fileName = message.fileName ?? 'file';
    final size = message.fileSize ?? 0;
    final sizeStr = _formatFileSize(size);
    final l10n = AppLocalizations.of(context)!;

    // Resolve sender name for "sends:" header
    final String senderLabel;
    if (incoming) {
      final rawName = stripWlmColorTags(contact.displayName);
      senderLabel = (rawName.isNotEmpty && rawName != contact.email)
          ? rawName
          : contact.email;
    } else {
      senderLabel = ref.read(msnpClientProvider).selfDisplayName;
    }

    return Column(
      crossAxisAlignment: incoming ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            l10n.messageSends(senderLabel),
            style: TextStyle(
              color: incoming
                  ? const Color(0xFF2364A6)
                  : const Color(0xFF1B7A1B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'Arial'],
            ),
          ),
        ),
        Align(
      alignment: incoming ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
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
            // Header
            Row(children: [
              const Icon(Icons.insert_drive_file_outlined,
                  size: 20, color: Color(0xFF2364A6)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B3146),
                    fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              sizeStr,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF5A758A),
                fontFamilyFallback: ['Segoe UI', 'Tahoma'],
              ),
            ),
            const SizedBox(height: 6),
            // Status / actions
            if (state == FileTransferState.offered && incoming)
              Row(children: [
                _ftActionBtn('Accept', const Color(0xFF2C8C3C), () {
                  ref
                      .read(chatProvider.notifier)
                      .acceptFileTransfer(message.fileTransferId ?? '');
                }),
                const SizedBox(width: 8),
                _ftActionBtn('Decline', const Color(0xFF9C3030), () {
                  ref
                      .read(chatProvider.notifier)
                      .declineFileTransfer(message.fileTransferId ?? '');
                }),
              ])
            else
              Text(
                _ftStateLabel(state, incoming),
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: state == FileTransferState.completed
                      ? const Color(0xFF2C8C3C)
                      : state == FileTransferState.failed ||
                              state == FileTransferState.declined
                          ? const Color(0xFF9C3030)
                          : const Color(0xFF375A78),
                  fontFamilyFallback: const ['Segoe UI', 'Tahoma'],
                ),
              ),
          ],
        ),
      ),
    ),  // close Align
      ],  // close Column children
    );  // close Column
  }

  Widget _ftActionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontFamilyFallback: ['Segoe UI', 'Tahoma'],
            )),
      ),
    );
  }

  String _ftStateLabel(FileTransferState state, bool incoming) {
    switch (state) {
      case FileTransferState.none:
        return '';
      case FileTransferState.offered:
        return incoming ? 'Waiting for your response...' : 'Waiting for response...';
      case FileTransferState.accepted:
        return 'Transfer accepted — starting...';
      case FileTransferState.transferring:
        return 'Transferring...';
      case FileTransferState.completed:
        return 'Transfer complete';
      case FileTransferState.declined:
        return 'Transfer declined';
      case FileTransferState.failed:
        return 'Transfer failed';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
      // Check if the newest message is an incoming nudge → trigger shake
      if (thread.length > _lastThreadSize && thread.isNotEmpty) {
        final newest = thread.last;
        if (newest.isNudge &&
            newest.from.toLowerCase() == contact.email.toLowerCase()) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _shakeController.forward(from: 0);
          });
        }
      }
      _lastThreadSize = thread.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollMessagesToBottom());
    }

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final dx = _shakeController.isAnimating
            ? sin(_shakeAnimation.value * pi * 6) * 8.0
            : 0.0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: Scaffold(
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
                    color: Color.lerp(
                      _chatAreaTint(contact),
                      Colors.white,
                      0.25,
                    )!.withOpacity(0.92),
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
                            color: _chatAreaTint(contact),
                            border: Border.all(color: const Color(0xFFB4C7D7)),
                          ),
                          child: ListView.builder(
                            controller: _messagesScrollController,
                            padding: const EdgeInsets.all(10),
                            itemCount: thread.length,
                            itemBuilder: (context, index) {
                              final message = thread[index];
                              final incoming = _isIncoming(message, contact.email);

                              // File transfer messages get a special widget
                              if (message.isFileTransfer) {
                                return _fileTransferBubble(
                                    message, incoming, contact);
                              }

                              // WLM 2009 flat format:
                              // Show sender header only when sender changes
                              final showHeader = index == 0 ||
                                  thread[index - 1].from != message.from ||
                                  thread[index - 1].isFileTransfer;

                              final rawDisplayName = stripWlmColorTags(contact.displayName);
                              final senderName = incoming
                                  ? (rawDisplayName.isNotEmpty &&
                                   rawDisplayName != contact.email
                                      ? rawDisplayName
                                      : contact.email)
                                  : null;
                              final selfName = ref.read(msnpClientProvider).selfDisplayName;

                              return Padding(
                                padding: EdgeInsets.only(
                                  top: showHeader && index > 0 ? 8 : 0,
                                  bottom: 1,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showHeader)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Text(
                                          incoming
                                              ? l10n.messageSays(senderName!)
                                              : l10n.messageMeSays(selfName),
                                          style: TextStyle(
                                            color: incoming
                                                ? const Color(0xFF2364A6)
                                                : const Color(0xFF1B7A1B),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            fontFamilyFallback: const [
                                              'Segoe UI',
                                              'Tahoma',
                                              'Arial'
                                            ],
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: Text.rich(
                                        TextSpan(children: [
                                          const TextSpan(
                                            text: '■ ',
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: Color(0xFF5A7A94),
                                            ),
                                          ),
                                          buildEmoticonSpan(
                                            message.body,
                                            TextStyle(
                                              color: message.isNudge
                                                  ? const Color(0xFFB02222)
                                                  : const Color(0xFF1B3146),
                                              fontSize: 14,
                                              fontFamilyFallback: const [
                                                'Segoe UI',
                                                'Tahoma',
                                                'Arial'
                                              ],
                                            ),
                                          ),
                                        ]),
                                      ),
                                    ),
                                  ],
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
    ),  // close Scaffold (child of AnimatedBuilder)
    );  // close AnimatedBuilder
  }

  Widget _titleBar(Contact contact) {
    final themeBase = _contactThemeBase(contact);
    final themeDark = _darken(themeBase, 0.18);
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
        gradient: LinearGradient(
          colors: [
            themeDark,
            themeBase,
          ],
        ),
      ),
      child: Row(
        children: [
          Image.asset(_assetWlmIcon, width: 16, height: 16),
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

        ],
      ),
    );
  }

  Widget _menuBar() {
    final contact = _currentContact();
    final themeBase = _contactThemeBase(contact);
    final menuTop = _lighten(themeBase, 0.35);
    final menuMidA = _lighten(themeBase, 0.28);
    final menuMidB = _lighten(themeBase, 0.20);
    final menuBottom = _lighten(themeBase, 0.12);
    return Container(
      height: 30,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            menuTop,
            menuMidA,
            menuMidB,
            menuBottom,
          ],
          stops: [0.0, 0.35, 0.5, 1.0],
        ),
      ),
      foregroundDecoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage(_assetChromeBarLight),
          // 9-slice: preserve 6px at left/right edges, stretch center
          centerSlice: const Rect.fromLTRB(6, 0, 594, 31),
          colorFilter: ColorFilter.mode(
            const Color(0xFF8AB8D8).withValues(alpha: 0.12),
            BlendMode.srcATop,
          ),
        ),
      ),
      child: Row(
        children: [
          // Windows 7 Explorer circular back button
          Win7BackButton(
            size: 26,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          // Vertical separator
          Container(
            width: 1,
            height: 18,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          // Send Files button
          GestureDetector(
            onTap: () => _pickAndSendFile(contact),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'Send Files',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 13,
                  fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'Arial'],
                ),
              ),
            ),
          ),
          // Vertical separator
          Container(
            width: 1,
            height: 18,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          // Invite contact button
          GestureDetector(
            onTap: () => _showInviteContactPicker(contact),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'Invite',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 13,
                  fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'Arial'],
                ),
              ),
            ),
          ),
        ],
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
    // 1. If the contact has a scene image file, use it.
    final scene = contact.scene;
    if (scene != null && scene.isNotEmpty) {
      // Scene value may be just a filename (e.g. "0001.png") or a full asset path.
      final assetPath = scene.contains('/')
          ? scene
          : 'assets/images/scenes/$scene';
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const WlmSceneBackground(height: 130),
      );
    }

    // 2. Use the contact's UBX <ColorScheme> as a colour gradient.
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

  /// Returns a light tint of the contact's color scheme for the chat
  /// transcript background. In WLM 2009, the message area picks up a
  /// visible hue from the contact scene/colour.
  Color _chatAreaTint(Contact contact) {
    final cs = contact.colorScheme;
    if (cs != null && cs.isNotEmpty && cs != '-1') {
      final parsed = int.tryParse(cs);
      if (parsed != null && parsed != 0) {
        final rgb = parsed < 0 ? (0xFFFFFF + parsed + 1) : parsed;
        final base = Color(0xFF000000 | (rgb & 0xFFFFFF));
        final hsl = HSLColor.fromColor(base);
        // WLM 2009 pastel tint — visible but soft.
        return hsl
            .withSaturation((hsl.saturation * 0.45).clamp(0.0, 1.0))
            .withLightness(0.90)
            .toColor();
      }
    }
    return Colors.white;
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
                      // Photo — inset ~10% to sit inside the aero frame center
                      Positioned(
                        top: 7, left: 7, right: 7, bottom: 7,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: _contactAvatar(contact, width: 54, height: 54),
                        ),
                      ),
                      // Aero glass frame — light tint preserving glass highlights
                      Positioned.fill(
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            _statusFrame(contact.status).withValues(alpha: 0.45),
                            BlendMode.srcATop,
                          ),
                          child: Image.asset(_assetAvatarFrame,
                              fit: BoxFit.fill),
                        ),
                      ),
                      // Status glow edge
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _statusFrame(contact.status).withValues(alpha: 0.7),
                              width: 1.5,
                            ),
                          ),
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
            padding: const EdgeInsets.only(bottom: 4, right: 0),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Photo — inset ~10% to sit inside the aero frame center
                  Positioned(
                    top: 5, left: 5, right: 5, bottom: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: _selfAvatar(selfAvatarPath, width: 42, height: 42),
                    ),
                  ),
                  // Aero glass frame — light tint preserving glass highlights
                  Positioned.fill(
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        _statusFrame(selfStatus).withValues(alpha: 0.45),
                        BlendMode.srcATop,
                      ),
                      child: Image.asset(_assetAvatarFrame, fit: BoxFit.fill),
                    ),
                  ),
                  // Status glow edge
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _statusFrame(selfStatus).withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Speech bubble triangle pointing from avatar to text field
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SizedBox(
              width: 8,
              height: 52,
              child: Center(
                child: CustomPaint(
                  size: const Size(8, 12),
                  painter: _SpeechTrianglePainter(color: const Color(0xFFE7EEF5)),
                ),
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
                      // Emoticon picker button
                      _emoticonButton(),
                      const Spacer(),
                      // Nudge button
                      GestureDetector(
                        onTap: () => _sendNudge(contact),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFE88A2A), Color(0xFFD06A10)],
                            ),
                            border: Border.all(color: const Color(0xFF8A4500)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // WLM nudge bell icon
                              Image.asset(
                                _assetNudgeIcon,
                                width: 16,
                                height: 16,
                                filterQuality: FilterQuality.none,
                              ),
                              const SizedBox(width: 4),
                              const Text('Nudge',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontFamilyFallback: [
                                        'Segoe UI',
                                        'Tahoma'
                                      ])),
                            ],
                          ),
                        ),
                      ),
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
      child: const SizedBox.shrink(),
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

  // ── Emoticon picker ──────────────────────────────────────────────────

  final GlobalKey _emoticonBtnKey = GlobalKey();

  Widget _emoticonButton() {
    return GestureDetector(
      key: _emoticonBtnKey,
      onTap: _toggleEmoticonPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        // Clip to a single 19×19 cell from the sprite sheet (cell 0 = smiley)
        child: SizedBox(
          width: 19,
          height: 19,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: 1520,
              maxHeight: 19,
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/images/extracted/msgsres/carved_png_9495208.png',
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
          // Dismiss scrim
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
                      offset: sel.baseOffset + code.length),
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

/// Paints a small left-pointing triangle for the speech bubble.
class _SpeechTrianglePainter extends CustomPainter {
  _SpeechTrianglePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SpeechTrianglePainter old) => old.color != color;
}
