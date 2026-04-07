import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;

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
      'assets/images/usertiles/new_default.png';
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
    return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  }

  Color _darken(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - delta).clamp(0.0, 1.0)).toColor();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only trigger a P2P fetch if the contact doesn't already have a
      // cached avatar.  Using force:true on every chat open causes a new
      // SB + INVITE cycle that, on timeout, wipes the existing avatar.
      final hasAvatar =
          widget.contact.avatarLocalPath != null &&
          widget.contact.avatarLocalPath!.isNotEmpty;
      if (!hasAvatar) {
        ref
            .read(msnpClientProvider)
            .requestAvatarFetchForContact(widget.contact.email, force: true);
      }
      // Refresh cached avatar (CrossTalk / persistent cache) for this contact.
      ref
          .read(contactsProvider.notifier)
          .refreshAvatarFor(widget.contact.email);
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollMessagesToBottom(),
    );
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
    _messagesScrollController.jumpTo(
      _messagesScrollController.position.maxScrollExtent,
    );
  }

  Future<void> _sendMessage(Contact contact) async {
    final body = _controller.text.trim();
    if (body.isEmpty) {
      return;
    }

    await ref
        .read(chatProvider.notifier)
        .sendMessage(to: contact.email, body: body);
    if (!mounted) {
      return;
    }
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollMessagesToBottom(),
    );
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollMessagesToBottom(),
    );
  }

  Future<void> _pickAndSendFile(Contact contact) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    await ref
        .read(chatProvider.notifier)
        .sendFile(to: contact.email, filePath: file.path!);
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollMessagesToBottom(),
      );
    }
  }

  void _showInviteContactPicker(Contact currentContact) {
    final contacts = ref.read(contactsProvider);
    final online = contacts
        .where(
          (c) =>
              c.status != PresenceStatus.appearOffline &&
              c.email.toLowerCase() != currentContact.email.toLowerCase(),
        )
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
          backgroundColor: const Color(0xFFF4F8FB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withOpacity(0.6)),
          ),
          child: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1A4978),
                        Color(0xFF3A8CC4),
                        Color(0xFF5CAEE0),
                        Color(0xFF2F7CB5),
                      ],
                      stops: [0.0, 0.40, 0.55, 1.0],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
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
                        subtitle: Text(
                          c.email,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          // CAL the contact into the existing switchboard
                          ref
                              .read(msnpClientProvider)
                              .inviteToSwitchboard(c.email);
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
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF4A6A84)),
                      ),
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

  Widget _fileTransferBubble(Message message, bool incoming, Contact contact) {
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
      crossAxisAlignment: incoming
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            l10n.messageSends(senderLabel),
            style: TextStyle(
              color: incoming
                  ? const Color(0xFF2A6A9E)
                  : const Color(0xFF2A7A3A),
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
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: incoming
                    ? [
                        Colors.white.withOpacity(0.60),
                        const Color(0xFFE8F0F8).withOpacity(0.65),
                      ]
                    : [
                        Colors.white.withOpacity(0.60),
                        const Color(0xFFE4F0E8).withOpacity(0.65),
                      ],
              ),
              border: Border.all(
                color: const Color(0xFFCBDAE8).withOpacity(0.50),
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A4978).withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file_outlined,
                      size: 20,
                      color: Color(0xFF3A8AC0),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2A3E50),
                          fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  sizeStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6A8FA8),
                    fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                  ),
                ),
                const SizedBox(height: 6),
                // Status / actions
                if (state == FileTransferState.offered && incoming)
                  Row(
                    children: [
                      _ftActionBtn('Accept', const Color(0xFF3A9A4A), () {
                        ref
                            .read(chatProvider.notifier)
                            .acceptFileTransfer(message.fileTransferId ?? '');
                      }),
                      const SizedBox(width: 8),
                      _ftActionBtn('Decline', const Color(0xFFA04040), () {
                        ref
                            .read(chatProvider.notifier)
                            .declineFileTransfer(message.fileTransferId ?? '');
                      }),
                    ],
                  )
                else
                  Text(
                    _ftStateLabel(state, incoming),
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: state == FileTransferState.completed
                          ? const Color(0xFF3A9A4A)
                          : state == FileTransferState.failed ||
                                state == FileTransferState.declined
                          ? const Color(0xFFA04040)
                          : const Color(0xFF5A8AAC),
                      fontFamilyFallback: const ['Segoe UI', 'Tahoma'],
                    ),
                  ),
              ],
            ),
          ),
        ), // close Align
      ], // close Column children
    ); // close Column
  }

  Widget _ftActionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withOpacity(0.85), color],
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFamilyFallback: ['Segoe UI', 'Tahoma'],
          ),
        ),
      ),
    );
  }

  String _ftStateLabel(FileTransferState state, bool incoming) {
    switch (state) {
      case FileTransferState.none:
        return '';
      case FileTransferState.offered:
        return incoming
            ? 'Waiting for your response...'
            : 'Waiting for response...';
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
    final isContactTyping = typingContacts.contains(
      contact.email.toLowerCase(),
    );
    final thread = ref
        .read(chatProvider.notifier)
        .threadForContact(contact.email);
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
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollMessagesToBottom(),
      );
    }

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
                _titleBar(contact),
                _menuBar(),
                _contactHeader(contact),
                // P2P status bar – only shown during active transfers
                Consumer(
                  builder: (ctx, cRef, _) {
                    final statusMap =
                        cRef.watch(p2pStatusProvider).asData?.value ?? {};
                    final p2pSt = statusMap[contact.email.toLowerCase()];
                    if (p2pSt == null ||
                        p2pSt.message.isEmpty ||
                        p2pSt.message == 'Avatar: idle') {
                      return const SizedBox.shrink();
                    }
                    return _p2pStatusBar(p2pSt);
                  },
                ),
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
                                      final incoming = _isIncoming(
                                        message,
                                        contact.email,
                                      );

                                      // File transfer messages get a special widget
                                      if (message.isFileTransfer) {
                                        return _fileTransferBubble(
                                          message,
                                          incoming,
                                          contact,
                                        );
                                      }

                                      // WLM 2009 flat format:
                                      // Show sender header only when sender changes
                                      final showHeader =
                                          index == 0 ||
                                          thread[index - 1].from !=
                                              message.from ||
                                          thread[index - 1].isFileTransfer;

                                      final rawDisplayName = stripWlmColorTags(
                                        contact.displayName,
                                      );
                                      final senderName = incoming
                                          ? (rawDisplayName.isNotEmpty &&
                                                    rawDisplayName !=
                                                        contact.email
                                                ? rawDisplayName
                                                : contact.email)
                                          : null;
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
                              if (isContactTyping)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.fromLTRB(
                                    10,
                                    0,
                                    10,
                                    6,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withOpacity(0.55),
                                        const Color(
                                          0xFFE4EEF6,
                                        ).withOpacity(0.60),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFCBDAE8,
                                      ).withOpacity(0.45),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.typingIndicator(
                                      stripWlmColorTags(contact.displayName),
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF5A7A94),
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      fontFamilyFallback: [
                                        'Segoe UI',
                                        'Tahoma',
                                        'Arial',
                                      ],
                                    ),
                                  ),
                                ),
                              _composeArea(
                                contact,
                                selfAvatarPath: selfAvatarPath,
                                selfStatus: ref
                                    .read(msnpClientProvider)
                                    .selfPresence,
                              ),
                            ],
                          ),
                        ), // close Container (BackdropFilter child)
                      ), // close BackdropFilter
                    ), // close ClipRRect
                  ), // close outer Container margin
                ),
                _footerStatus(),
              ],
            ),
          ),
        ),
      ), // close Scaffold (child of AnimatedBuilder)
    ); // close AnimatedBuilder
  }

  Widget _titleBar(Contact contact) {
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
            'assets/images/extracted/app_logo_24.png',
            width: 18,
            height: 18,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${stripWlmColorTags(contact.displayName)} <${contact.email}>',
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
    final contact = _currentContact();
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
          GestureDetector(
            onTap: () => _pickAndSendFile(contact),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'Send Files',
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
          GestureDetector(
            onTap: () => _showInviteContactPicker(contact),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'Invite',
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

  Widget _p2pStatusBar(P2pStatus status) {
    final isComplete = status.message.contains('Complete');
    final isIdle = status.message == 'Avatar: idle';
    final showProgress =
        status.totalSize > 0 && status.bytesReceived > 0 && !isComplete;

    final Color topColor;
    final Color bottomColor;
    final Color borderColor;
    final Color textColor;
    final Color progressBg;
    final Color progressFg;

    if (isComplete) {
      topColor = const Color(0xFFD8F0D8);
      bottomColor = const Color(0xFFC4E4C4);
      borderColor = const Color(0xFFB4D8B4).withOpacity(0.7);
      textColor = const Color(0xFF2A6A2A);
      progressBg = const Color(0xFFD8F0D8);
      progressFg = const Color(0xFF4AA84A);
    } else {
      topColor = const Color(0xFFFFF2D4);
      bottomColor = const Color(0xFFFFE8B4);
      borderColor = const Color(0xFFE8D0A0).withOpacity(0.7);
      textColor = const Color(0xFF6A5020);
      progressBg = const Color(0xFFFFF2D4);
      progressFg = const Color(0xFFD4A030);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, bottomColor],
        ),
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A4978).withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
              fontWeight: FontWeight.w600,
              fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'Arial'],
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: status.progress,
                backgroundColor: progressBg,
                color: progressFg,
                minHeight: 4,
              ),
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
        errorBuilder: (_, _, _) => const WlmSceneBackground(height: 130),
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
    final lighter = hsl
        .withLightness((hsl.lightness + 0.25).clamp(0.0, 0.95))
        .toColor();
    final lightest = hsl
        .withLightness((hsl.lightness + 0.45).clamp(0.0, 0.97))
        .toColor();
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
    FontWeight fontWeight = FontWeight.w400,
  }) {
    final segments = parseWlmColorTags(raw, defaultColor: defaultColor);
    return segments
        .map(
          (s) => TextSpan(
            text: s.text,
            style: TextStyle(
              color: s.color,
              fontSize: fontSize,
              fontWeight: fontWeight,
              fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'Arial'],
              shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
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
          // Contact info overlay
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 7,
                        left: 7,
                        right: 7,
                        bottom: 7,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: _contactAvatar(contact, width: 58, height: 58),
                        ),
                      ),
                      Positioned.fill(
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            _statusFrame(
                              contact.status,
                            ).withValues(alpha: 0.35),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: _buildColoredName(
                            contact.displayName,
                            defaultColor: const Color(0xFF1A3A5C),
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '(${_statusLabel(context, contact.status)})',
                        style: TextStyle(
                          color: const Color(0xFF5A7A94),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          fontFamilyFallback: const [
                            'Segoe UI',
                            'Tahoma',
                            'Arial',
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      if ((contact.nowPlaying != null &&
                              contact.nowPlaying!.isNotEmpty) ||
                          (contact.personalMessage != null &&
                              contact.personalMessage!.isNotEmpty))
                        Text(
                          contact.nowPlaying != null &&
                                  contact.nowPlaying!.isNotEmpty
                              ? '♫ ${contact.nowPlaying}'
                              : contact.personalMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF6A8FA8),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontFamilyFallback: const [
                              'Segoe UI',
                              'Tahoma',
                              'Arial',
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

  Widget _composeArea(
    Contact contact, {
    required String? selfAvatarPath,
    PresenceStatus selfStatus = PresenceStatus.online,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Balloon + avatar row ──
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
              // Triangle tail pointing from avatar to balloon — overlaps
              // the balloon border by 4px so it looks seamlessly attached.
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
              // Acrylic composer balloon — matching main window card style
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
                      // Subtle glass highlight bar
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
                      // Text field
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                        child: SizedBox(
                          height: 52,
                          child: TextField(
                            controller: _controller,
                            onChanged: (_) => _sendTypingPulse(contact),
                            onSubmitted: (_) => _sendMessage(contact),
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
                      // Toolbar
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                        child: Row(
                          children: [
                            _emoticonButton(),
                            const Spacer(),
                            // Nudge button — warm amber, softer and rounder
                            GestureDetector(
                              onTap: () => _sendNudge(contact),
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
                            // Send button — soft aqua-blue
                            GestureDetector(
                              onTap: () => _sendMessage(contact),
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

  Widget _footerStatus() {
    return const SizedBox(height: 4);
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

/// Paints a speech-bubble tail (triangle) pointing left from the balloon,
/// with border matching the acrylic composer balloon.
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
    // Clip the right 4px so the tail disappears behind the balloon border.
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width - 3, size.height));
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height * 0.5)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, fill);
    // Only draw the two outer edges (top-left, bottom-left)
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
