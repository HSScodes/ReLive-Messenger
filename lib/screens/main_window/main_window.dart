import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wlm_project/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/contact.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/profile_avatar_provider.dart';
import '../../utils/presence_status.dart';
import '../../utils/wlm_color_tags.dart';
import '../chat/chat_window.dart';

/* ═══════════════════════════════════════════════════════════════════════════
   MainWindowScreen — WLM 2009 Contact-list, redesigned for phone / touch
   ═══════════════════════════════════════════════════════════════════════════ */

class MainWindowScreen extends ConsumerStatefulWidget {
  const MainWindowScreen({super.key});

  @override
  ConsumerState<MainWindowScreen> createState() => _MainWindowScreenState();
}

class _MainWindowScreenState extends ConsumerState<MainWindowScreen> {
  // ── Asset paths ────────────────────────────────────────────────────────
  static const _assetAvatarFrame =
      'assets/images/extracted/msgsres/carved_png_9812096.png';
  static const _assetAvatarUser =
      'assets/images/extracted/msgsres/carved_png_9801032.png';
  static const _assetArrow =
      'assets/images/extracted/msgsres/carved_png_10968848.png';
  static const _assetHelp =
      'assets/images/extracted/msgsres/carved_png_9727920.png';
  static const _assetToolbarA =
      'assets/images/extracted/msgsres/carved_png_9663952.png';
  static const _assetToolbarB =
      'assets/images/extracted/msgsres/carved_png_9783656.png';
  static const _assetToolbarC =
      'assets/images/extracted/msgsres/carved_png_9835392.png';
  static const _assetStatusOnline =
      'assets/images/extracted/msgsres/carved_png_9375216.png';
  static const _assetStatusBusy =
      'assets/images/extracted/msgsres/carved_png_9387680.png';
  static const _assetStatusAway =
      'assets/images/extracted/msgsres/carved_png_9380960.png';
  static const _assetStatusOffline =
      'assets/images/extracted/msgsres/carved_png_9394296.png';

  // ── State ──────────────────────────────────────────────────────────────
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _psmCtrl = TextEditingController();
  bool _editingPsm = false;
  bool _favExpanded = false;
  bool _grpExpanded = false;
  bool _onExpanded = true;
  bool _offExpanded = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _psmCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  String _statusAsset(PresenceStatus s) {
    switch (s) {
      case PresenceStatus.online:
        return _assetStatusOnline;
      case PresenceStatus.busy:
        return _assetStatusBusy;
      case PresenceStatus.away:
        return _assetStatusAway;
      case PresenceStatus.appearOffline:
        return _assetStatusOffline;
    }
  }

  String _statusLabel(BuildContext context, PresenceStatus s) {
    final l10n = AppLocalizations.of(context)!;
    switch (s) {
      case PresenceStatus.online:
        return l10n.statusOnline;
      case PresenceStatus.busy:
        return l10n.statusBusy;
      case PresenceStatus.away:
        return l10n.statusAway;
      case PresenceStatus.appearOffline:
        return l10n.statusAppearOffline;
    }
  }

  Color _statusAccent(PresenceStatus s) {
    switch (s) {
      case PresenceStatus.online:
        return const Color(0xFF42D833);
      case PresenceStatus.away:
        return const Color(0xFFE2C92D);
      case PresenceStatus.busy:
        return const Color(0xFFD94A4A);
      case PresenceStatus.appearOffline:
        return const Color(0xFF94A1AE);
    }
  }

  Widget _img(String asset,
      {double? w, double? h, BoxFit fit = BoxFit.contain}) {
    return Image.asset(asset,
        width: w,
        height: h,
        fit: fit,
        errorBuilder: (_, __, ___) => SizedBox(
            width: w,
            height: h,
            child: const Icon(Icons.image_not_supported,
                size: 14, color: Color(0xFF4F6E88))));
  }

  Widget _contactAvatarImg(Contact c, {required bool online}) {
    final p = c.avatarLocalPath;
    Widget img;
    if (p != null && p.isNotEmpty && File(p).existsSync()) {
      img = Image.file(File(p), fit: BoxFit.cover);
    } else {
      img = Image.asset(_assetAvatarUser, fit: BoxFit.cover);
    }
    return Opacity(opacity: online ? 1 : 0.55, child: img);
  }

  Widget _selfAvatarImg(String? path) {
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return Image.file(File(path), width: 46, height: 46, fit: BoxFit.cover);
    }
    return _img(_assetAvatarUser, w: 46, h: 46, fit: BoxFit.cover);
  }

  // ── Status picker bottom-sheet ─────────────────────────────────────────
  void _showStatusPicker() {
    final client = ref.read(msnpClientProvider);
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFEAF1F8),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFB3C5D4),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(l10n.changeStatus,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E4F82),
                    fontFamilyFallback: ['Segoe UI', 'Tahoma'])),
          ),
          const Divider(height: 1, color: Color(0xFFB5CBE0)),
          for (final s in PresenceStatus.values)
            ListTile(
              leading: _img(_statusAsset(s), w: 18, h: 18),
              title: Text(_statusLabel(context, s),
                  style: const TextStyle(
                      fontSize: 16,
                      fontFamilyFallback: ['Segoe UI', 'Tahoma'])),
              onTap: () {
                Navigator.pop(ctx);
                client.setPresence(s);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── PSM editing ────────────────────────────────────────────────────────
  void _startPsmEdit() {
    _psmCtrl.text = ref.read(msnpClientProvider).selfPsm;
    setState(() => _editingPsm = true);
  }

  void _commitPsm() {
    ref.read(msnpClientProvider).setPersonalMessage(_psmCtrl.text.trim());
    setState(() => _editingPsm = false);
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authProvider);
    ref.watch(chatProvider);
    final contacts = ref.watch(contactsProvider);
    final selfAvatarPath = ref.watch(profileAvatarProvider);
    final client = ref.watch(msnpClientProvider);

    // Partition contacts
    final online = <Contact>[];
    final offline = <Contact>[];
    for (final c in contacts) {
      (c.status == PresenceStatus.appearOffline ? offline : online).add(c);
    }

    // Search filter
    final q = _searchQuery.toLowerCase();
    List<Contact> filter(List<Contact> l) => q.isEmpty
        ? l
        : l
            .where((c) =>
                stripWlmColorTags(c.displayName).toLowerCase().contains(q) ||
                c.email.toLowerCase().contains(q))
            .toList();

    final fOn = filter(online)
      ..sort((a, b) => stripWlmColorTags(a.displayName)
          .toLowerCase()
          .compareTo(stripWlmColorTags(b.displayName).toLowerCase()));
    final fOff = filter(offline)
      ..sort((a, b) => stripWlmColorTags(a.displayName)
          .toLowerCase()
          .compareTo(stripWlmColorTags(b.displayName).toLowerCase()));

    final email = auth.email ?? 'user@live.com';
    final psm = client.selfPsm;
    final selfStatus = client.selfPresence;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF53B8EA), Color(0xFFE9F0F7)],
            stops: [0.0, 0.30],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            // ── Title bar ──
            _titleBar(),
            // ── Profile header ──
            _profileHeader(
                email: email,
                avatarPath: selfAvatarPath,
                psm: psm,
                selfStatus: selfStatus),
            // ── Search ──
            _searchBar(),
            // ── Contact list ──
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  border: Border.all(color: const Color(0xFF88B3D4)),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3A7DB8).withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  children: [
                    _group(l10n.contactsFavorites, 0, _favExpanded,
                        () => setState(() => _favExpanded = !_favExpanded), []),
                    _group(l10n.contactsGroups, 0, _grpExpanded,
                        () => setState(() => _grpExpanded = !_grpExpanded), []),
                    _group(
                      l10n.contactsAvailable,
                        fOn.length,
                        _onExpanded,
                        () => setState(() => _onExpanded = !_onExpanded),
                        [for (final c in fOn) _tile(c, online: true)]),
                    _group(
                      l10n.contactsOffline,
                        fOff.length,
                        _offExpanded,
                        () => setState(() => _offExpanded = !_offExpanded),
                        [for (final c in fOff) _tile(c, online: false)]),
                    if (contacts.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 12),
                      child: Text(l10n.syncingContacts,
                            style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF5D6D7A),
                                fontFamilyFallback: [
                                  'Segoe UI',
                                  'Tahoma',
                                  'Arial'
                                ])),
                      ),
                  ],
                ),
              ),
            ),
            // ── Bottom bar ──
            _bottomBar(),
          ]),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  TITLE BAR
  // ═════════════════════════════════════════════════════════════════════════
  Widget _titleBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Color(0xFF1E4F82), Color(0xFF2B78B5)]),
      ),
      child: Row(children: [
        _img(_assetToolbarC, w: 14, h: 14),
        const SizedBox(width: 8),
        Text(l10n.windowsLiveMessenger,
          style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'])),
        const Spacer(),
        _captionBtn('−'),
        _captionBtn('□'),
        _captionBtn('×', close: true),
      ]),
    );
  }

  Widget _captionBtn(String t, {bool close = false}) {
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
      child: Text(t,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              shadows: [
                Shadow(color: Color(0x60000000), blurRadius: 2)
              ])),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  PROFILE HEADER  (avatar + name dropdown + PSM)
  // ═════════════════════════════════════════════════════════════════════════
  Widget _profileHeader({
    required String email,
    required String? avatarPath,
    required String psm,
    required PresenceStatus selfStatus,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final frameColor = _statusAccent(selfStatus);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD4F0FD),
            Color(0xFFA2DDF7),
            Color(0xFF82D0F0),
            Color(0xFF6EC5EB),
          ],
          stops: [0.0, 0.3, 0.6, 1.0],
        ),
        // Subtle bottom highlight line (Aero glass)
        border: const Border(
          bottom: BorderSide(color: Color(0x40FFFFFF), width: 1),
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar (tap → status picker) with status-coloured glow
        GestureDetector(
          onTap: _showStatusPicker,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: frameColor.withOpacity(0.55),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(alignment: Alignment.center, children: [
              // Status-coloured border behind the frame
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: frameColor, width: 2.5),
                ),
              ),
              _img(_assetAvatarFrame, w: 62, h: 62, fit: BoxFit.fill),
              ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: _selfAvatarImg(avatarPath)),
              // Status icon overlay bottom-right
              Positioned(
                right: 0,
                bottom: 0,
                child: _img(_statusAsset(selfStatus), w: 16, h: 16),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        // Right side: name dropdown + PSM
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Name / status dropdown ──
              GestureDetector(
                onTap: _showStatusPicker,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.55),
                    border: Border.all(
                        color: const Color(0xFF77A8C8).withOpacity(0.7)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF243E57),
                              fontFamilyFallback: [
                                'Segoe UI',
                                'Tahoma',
                                'Arial'
                              ])),
                    ),
                    _img(_assetArrow, w: 11, h: 10),
                  ]),
                ),
              ),
              const SizedBox(height: 5),
              // ── PSM (tap to edit) ──
              GestureDetector(
                onTap: _startPsmEdit,
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.40),
                    border: Border.all(
                        color: const Color(0xFF92BCD5).withOpacity(0.6)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: _editingPsm
                      ? Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _psmCtrl,
                              autofocus: true,
                              onSubmitted: (_) => _commitPsm(),
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1F3B57),
                                  fontFamilyFallback: [
                                    'Segoe UI',
                                    'Tahoma'
                                  ]),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintText: l10n.quickSharePlaceholder,
                                hintStyle: const TextStyle(
                                    color: Color(0xFF8AA2BD), fontSize: 13),
                              ),
                            ),
                          ),
                          GestureDetector(
                              onTap: _commitPsm,
                              child: const Icon(Icons.check,
                                  size: 16, color: Color(0xFF2B6A9E))),
                        ])
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            psm.isNotEmpty
                                ? psm
                              : l10n.quickSharePlaceholder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                color: psm.isNotEmpty
                                    ? const Color(0xFF1F3B57)
                                    : const Color(0xFF8AA2BD),
                                fontFamilyFallback: const [
                                  'Segoe UI',
                                  'Tahoma',
                                  'Arial'
                                ]),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  SEARCH BAR
  // ═════════════════════════════════════════════════════════════════════════
  Widget _searchBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 6, 6, 4),
      height: 36,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE3EFF7), Color(0xFFCFDEEB)],
        ),
        border: Border.all(color: const Color(0xFF8EB5D1)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1F3B57),
                fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial']),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                hintText: l10n.searchContactsWeb,
              hintStyle:
                  const TextStyle(color: Color(0xFF8AA2BD), fontSize: 14),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(Icons.close,
                          size: 16, color: Color(0xFF7A95B0)))
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 6),
        _img(_assetToolbarA, w: 16, h: 16),
        const SizedBox(width: 8),
        _img(_assetToolbarB, w: 16, h: 16),
        const SizedBox(width: 8),
        _img(_assetHelp, w: 16, h: 16),
      ]),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  EXPANDABLE GROUP
  // ═════════════════════════════════════════════════════════════════════════
  Widget _group(String title, int count, bool expanded, VoidCallback toggle,
      List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: toggle,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
          child: Row(children: [
            Icon(
                expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                size: 18,
                color: const Color(0xFF6A8FB5)),
            const SizedBox(width: 2),
            Text('$title ($count)',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2B5A92),
                    fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'])),
          ]),
        ),
      ),
      if (expanded) ...children,
    ]);
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  CONTACT TILE
  // ═════════════════════════════════════════════════════════════════════════
  Widget _tile(Contact contact, {required bool online}) {
    final segments = parseWlmColorTags(contact.displayName,
        defaultColor:
            online ? const Color(0xFF0A3A7D) : const Color(0xFF707070));

    return InkWell(
      onTap: () {
        ref.read(activeChatEmailProvider.notifier).setActive(contact.email);
        ref
            .read(contactsProvider.notifier)
            .resetUnreadForEmail(contact.email);
        Navigator.of(context)
            .push(MaterialPageRoute(
                builder: (_) => ChatWindowScreen(contact: contact)))
            .then((_) {
          ref
              .read(activeChatEmailProvider.notifier)
              .clearActive(contact.email);
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        child: Row(children: [
          // ── Avatar ──
          SizedBox(
            width: 38,
            height: 38,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: Opacity(
                  opacity: online ? 1 : 0.55,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color:
                              _statusAccent(contact.status).withOpacity(0.85),
                          width: 1.8),
                      boxShadow: online
                          ? [
                              BoxShadow(
                                  color: _statusAccent(contact.status)
                                      .withOpacity(0.30),
                                  blurRadius: 5,
                                  spreadRadius: 0.3)
                            ]
                          : [],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: online ? 1 : 0.55,
                  child: Image.asset(_assetAvatarFrame, fit: BoxFit.fill),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: _contactAvatarImg(contact, online: online),
                  ),
                ),
              ),
              if (online)
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: _img(_statusAsset(contact.status),
                      w: 14, h: 14, fit: BoxFit.fill),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          // ── Name + subtitle ──
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(
                TextSpan(
                  children: segments
                      .map((s) => TextSpan(
                          text: s.text,
                          style: TextStyle(
                              color:
                                  online ? s.color : s.color.withOpacity(0.6),
                              fontSize: 15,
                              fontFamilyFallback: const [
                                'Segoe UI',
                                'Tahoma',
                                'Arial'
                              ])))
                      .toList(),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if ((contact.nowPlaying ?? '').isNotEmpty)
                Text('♫ ${contact.nowPlaying!}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0A5EC2),
                        fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial']))
              else if ((contact.personalMessage ?? '').isNotEmpty)
                Text(contact.personalMessage!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5A7A94),
                        fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'])),
            ]),
          ),
          // ── Unread badge ──
          Consumer(
            builder: (context, trailingRef, _) {
              final unread = trailingRef.watch(contactsProvider.select((cl) {
                for (final c in cl) {
                  if (c.email.toLowerCase() == contact.email.toLowerCase()) {
                    return c.unreadCount;
                  }
                }
                return 0;
              }));
              if (unread <= 0) return const SizedBox.shrink();
              return Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE11A1A),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFFFFF1B3), width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x55A50000),
                        blurRadius: 5,
                        offset: Offset(0, 1))
                  ],
                ),
                child: Text('$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'])),
              );
            },
          ),
        ]),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  BOTTOM BAR
  // ═════════════════════════════════════════════════════════════════════════
  Widget _bottomBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F0F6), Color(0xFFD5E2ED)],
        ),
        border: const Border(top: BorderSide(color: Color(0xFFAAC5DB))),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.6),
            offset: const Offset(0, -1),
            blurRadius: 0,
          ),
        ],
      ),
        child: Text(l10n.spaceHeyFooter,
          style: const TextStyle(
              color: Color(0xFF223548),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'])),
    );
  }
}
