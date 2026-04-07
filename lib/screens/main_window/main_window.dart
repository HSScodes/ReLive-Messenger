import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wlm_project/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/contact.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/profile_avatar_provider.dart';
import '../../utils/presence_status.dart';
import '../../utils/wlm_color_tags.dart';
import '../chat/chat_window.dart';
import '../login/login_screen.dart';

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

  static const _assetToolbarC =
      'assets/images/extracted/msgsres/carved_png_9835392.png';
  static const _assetGroupArrow =
      'assets/images/extracted/msgsres/carved_png_10808928.png';
  static const _assetStatusOnline =
      'assets/images/extracted/msgsres/carved_png_9375216.png';
  static const _assetStatusBusy =
      'assets/images/extracted/msgsres/carved_png_9387680.png';
  static const _assetStatusAway =
      'assets/images/extracted/msgsres/carved_png_9380960.png';
  static const _assetStatusOffline =
      'assets/images/extracted/msgsres/carved_png_9394296.png';
    static const _assetAddContact =
      'assets/images/extracted/msgsres/carved_png_11071608.png';
    static const _assetBuddyGreen =
      'assets/images/extracted/msgsres/carved_png_9375216.png';

  // ── State ──────────────────────────────────────────────────────────────
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _psmCtrl = TextEditingController();
  final GlobalKey _nameDropdownKey = GlobalKey();
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
        return const Color(0xFF39FF14);
      case PresenceStatus.away:
        return const Color(0xFFE2C92D);
      case PresenceStatus.busy:
        return const Color(0xFFD94A4A);
      case PresenceStatus.appearOffline:
        return const Color(0xFF94A1AE);
    }
  }

  Color _mainThemeTopColor(String colorScheme) {
    if (colorScheme.isNotEmpty && colorScheme != '-1') {
      final parsed = int.tryParse(colorScheme);
      if (parsed != null && parsed != 0) {
        final rgb = parsed < 0 ? (0xFFFFFF + parsed + 1) : parsed;
        return Color(0xFF000000 | (rgb & 0xFFFFFF));
      }
    }
    return const Color(0xFF53B8EA);
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
    // Prefer DDP (dynamic display picture / animated GIF) over static avatar.
    final p = c.ddpLocalPath ?? c.avatarLocalPath;
    if (p != null && p.isNotEmpty && File(p).existsSync()) {
      return Image.file(File(p), fit: BoxFit.cover);
    }
    return Image.asset(_assetAvatarUser, fit: BoxFit.cover);
  }

  Widget _selfAvatarImg(String? path) {
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return Image.file(File(path), width: 46, height: 46, fit: BoxFit.cover);
    }
    return _img(_assetAvatarUser, w: 46, h: 46, fit: BoxFit.cover);
  }

  // ── Status picker popup menu (WLM 2009 style) ──────────────────────────
  void _showStatusPicker() {
    final client = ref.read(msnpClientProvider);
    final l10n = AppLocalizations.of(context)!;

    // Anchor to the name dropdown row via its GlobalKey
    final RenderBox? box =
        _nameDropdownKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset topLeft = box.localToGlobal(Offset.zero);
    final Size size = box.size;

    final menuItems = <PopupMenuEntry<String>>[
      // ── Status options ──
      for (final s in PresenceStatus.values)
        PopupMenuItem<String>(
          value: s.name,
          height: 32,
          child: Row(children: [
            _img(_statusAsset(s), w: 14, h: 14),
            const SizedBox(width: 10),
            Text(_statusLabel(context, s),
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1B2A38),
                    fontFamilyFallback: ['Segoe UI', 'Tahoma'])),
          ]),
        ),
      const PopupMenuDivider(height: 1),
      // Sign out
      PopupMenuItem<String>(
        value: 'signout',
        height: 32,
        child: Row(children: [
          const SizedBox(width: 24),
          Expanded(
            child: Text(l10n.signOutHere,
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1B2A38),
                    fontFamilyFallback: ['Segoe UI', 'Tahoma'])),
          ),
        ]),
      ),
      const PopupMenuDivider(height: 1),
      // Change display picture
      PopupMenuItem<String>(
        value: 'change_dp',
        height: 30,
        child: Row(children: [
          const SizedBox(width: 24),
          Text(l10n.changeDisplayPicture,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1B2A38),
                  fontFamilyFallback: ['Segoe UI', 'Tahoma'])),
        ]),
      ),
      // Change scene
      PopupMenuItem<String>(
        value: 'change_scene',
        height: 30,
        child: Row(children: [
          const SizedBox(width: 24),
          Text(l10n.changeScene,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1B2A38),
                  fontFamilyFallback: ['Segoe UI', 'Tahoma'])),
        ]),
      ),
      // Change display name
      PopupMenuItem<String>(
        value: 'change_name',
        height: 30,
        child: Row(children: [
          const SizedBox(width: 24),
          Text(l10n.changeDisplayName,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1B2A38),
                  fontFamilyFallback: ['Segoe UI', 'Tahoma'])),
        ]),
      ),
    ];

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        topLeft.dy + size.height + 2,
        topLeft.dx + size.width,
        0,
      ),
      color: const Color(0xFFF5F8FB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: const BorderSide(color: Color(0xFFAABFCF)),
      ),
      items: menuItems,
    ).then((value) {
      if (value == null || !mounted) return;
      if (value == 'signout') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        return;
      }
      if (value == 'change_dp') {
        _showDisplayPicturePicker();
        return;
      }
      if (value == 'change_scene') {
        _showScenePicker();
        return;
      }
      if (value == 'change_name') {
        _showChangeDisplayNameDialog();
        return;
      }
      // Status change
      final status = PresenceStatus.values
          .where((s) => s.name == value)
          .firstOrNull;
      if (status != null) {
        client.setPresence(status);
        setState(() {});
      }
    });
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

    // Pre-compute stripped sort keys once per contact (avoid regex in comparators).
    final _sortKeys = <String, String>{};
    String sortKeyOf(Contact c) =>
        _sortKeys[c.email] ??= stripWlmColorTags(c.displayName).toLowerCase();

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
                sortKeyOf(c).contains(q) ||
                c.email.toLowerCase().contains(q))
            .toList();

    final fOn = filter(online)
      ..sort((a, b) => sortKeyOf(a).compareTo(sortKeyOf(b)));
    final fOff = filter(offline)
      ..sort((a, b) => sortKeyOf(a).compareTo(sortKeyOf(b)));

    // Build favorites list from all contacts
    final contactsNotifier = ref.read(contactsProvider.notifier);
    final favEmails = contactsNotifier.favoriteEmails;
    final fFav = contacts
        .where((c) => favEmails.contains(c.email.toLowerCase()))
        .toList()
      ..sort((a, b) => sortKeyOf(a).compareTo(sortKeyOf(b)));

    final displayName = client.selfDisplayName;
    final psm = client.selfPsm;
    final selfStatus = client.selfPresence;
    final topThemeColor = _mainThemeTopColor(client.selfColorScheme);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              topThemeColor,
              const Color(0xFFFFFFFF),
            ],
            stops: [0.0, 0.30],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            // ── Title bar ──
            _titleBar(),
            // ── Profile header ──
            _profileHeader(
                displayName: displayName,
                avatarPath: selfAvatarPath,
                psm: psm,
                selfStatus: selfStatus),
            // ── Search + Add Contact ──
            Row(
              children: [
                Expanded(child: _searchBar()),
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 6),
                  child: GestureDetector(
                    onTap: _showAddContactDialog,
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Center(
                            child: Image.asset(
                              _assetBuddyGreen,
                              width: 28,
                              height: 28,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                          Positioned(
                            right: -1,
                            bottom: 0,
                            child: Image.asset(
                              _assetAddContact,
                              width: 14,
                              height: 14,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
                    _group(l10n.contactsFavorites, fFav.length, _favExpanded,
                        () => setState(() => _favExpanded = !_favExpanded),
                        [for (final c in fFav) _tile(c, online: c.status != PresenceStatus.appearOffline)]),
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

  BoxDecoration _defaultHeaderDecoration() {
    return const BoxDecoration(
      gradient: LinearGradient(
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
      border: Border(
        bottom: BorderSide(color: Color(0x40FFFFFF), width: 1),
      ),
    );
  }

  Widget _profileHeader({
    required String displayName,
    required String? avatarPath,
    required String psm,
    required PresenceStatus selfStatus,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final frameColor = _statusAccent(selfStatus);
    final client = ref.read(msnpClientProvider);
    final selfScene = client.selfScene;
    final selfColorScheme = client.selfColorScheme;

    // Determine background decoration based on selected scene/color
    BoxDecoration headerDecoration;
    final scene = selfScene;
    final cs = selfColorScheme;

    if (scene.isNotEmpty) {
      // Scene image as background
      final assetPath = scene.contains('/')
          ? scene
          : 'assets/images/scenes/$scene';
      headerDecoration = BoxDecoration(
        image: DecorationImage(
          image: AssetImage(assetPath),
          fit: BoxFit.cover,
          onError: (_, __) {},
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0x40FFFFFF), width: 1),
        ),
      );
    } else if (cs.isNotEmpty && cs != '-1') {
      final parsed = int.tryParse(cs);
      if (parsed != null && parsed != 0) {
        final rgb = parsed < 0 ? (0xFFFFFF + parsed + 1) : parsed;
        final baseColor = Color(0xFF000000 | (rgb & 0xFFFFFF));
        final hsl = HSLColor.fromColor(baseColor);
        final lighter = hsl.withLightness((hsl.lightness + 0.25).clamp(0.0, 0.95)).toColor();
        final lightest = hsl.withLightness((hsl.lightness + 0.45).clamp(0.0, 0.97)).toColor();
        headerDecoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [lightest, lighter, baseColor],
          ),
          border: const Border(
            bottom: BorderSide(color: Color(0x40FFFFFF), width: 1),
          ),
        );
      } else {
        headerDecoration = _defaultHeaderDecoration();
      }
    } else {
      headerDecoration = _defaultHeaderDecoration();
    }

    // Build an optional bottom-edge gradient that fades the scene into the
    // window gradient below (mimics WLM 2009's scene blending).
    BoxDecoration? sceneFadeOverlay;
    if (scene.isNotEmpty) {
      final fadeColor = _mainThemeTopColor(selfColorScheme);
      sceneFadeOverlay = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            fadeColor.withOpacity(0.0),
            fadeColor.withOpacity(0.0),
            fadeColor.withOpacity(0.45),
          ],
          stops: const [0.0, 0.60, 1.0],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: headerDecoration,
      foregroundDecoration: sceneFadeOverlay,
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
              // Photo — inset ~15.5% to sit inside the aero frame center
              Positioned(
                top: 10, left: 10, right: 10, bottom: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: _selfAvatarImg(avatarPath),
                ),
              ),
              // Aero glass frame, recolored by current status
              Positioned.fill(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    frameColor.withValues(alpha: 0.85),
                    BlendMode.srcATop,
                  ),
                  child: Image.asset(_assetAvatarFrame, fit: BoxFit.fill),
                ),
              ),
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
                  key: _nameDropdownKey,
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
                      child: Text(displayName,
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
      ]),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  EXPANDABLE GROUP
  // ═════════════════════════════════════════════════════════════════════════

  void _showAddContactDialog() {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFF0F4F8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFF7A9BB5)),
        ),
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Blue gradient header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  'Add a Contact',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                  ),
                ),
              ),
              // Description
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Text(
                  'Enter the email address of the person you want to add to your contact list.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF243E57),
                    fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
                  ),
                ),
              ),
              // Email field
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Instant Messaging Address:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B5A7C),
                        fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'example@hotmail.com',
                        hintStyle: const TextStyle(
                          fontSize: 12, color: Color(0xFF9BB0C4),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(2),
                          borderSide: const BorderSide(color: Color(0xFF8AAFC8)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(2),
                          borderSide: const BorderSide(color: Color(0xFF8AAFC8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(2),
                          borderSide: const BorderSide(
                              color: Color(0xFF3678B0), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Divider
              const Divider(height: 1, color: Color(0xFFBFD3E2)),
              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Cancel
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFFFFF), Color(0xFFE8E8E8)],
                          ),
                          border: Border.all(color: const Color(0xFFADBDCD)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1B2A38),
                              fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                            )),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Add
                    GestureDetector(
                      onTap: () {
                        final email = emailCtrl.text.trim();
                        if (email.isNotEmpty && email.contains('@')) {
                          ref.read(msnpClientProvider).addContact(email);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Contact $email added.')),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF5A9AD0), Color(0xFF3678B0)],
                          ),
                          border: Border.all(color: const Color(0xFF1E4F82)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('Add Contact',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                            )),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(String title, int count, bool expanded, VoidCallback toggle,
      List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: toggle,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
          child: Row(children: [
            // WLM 2009 triangle arrow — right for collapsed, rotated 90° for expanded
            Transform.rotate(
              angle: expanded ? 1.5708 : 0, // pi/2 radians = 90°
              child: Image.asset(
                _assetGroupArrow,
                width: 9,
                height: 11,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 4),
            Text('$title ($count)',
                style: const TextStyle(
                    fontSize: 15,
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
  //  CONTACT CONTEXT MENU (long-press)
  // ═════════════════════════════════════════════════════════════════════════
  void _showContactMenu(Contact contact) {
    final notifier = ref.read(contactsProvider.notifier);
    final isFav = notifier.isFavorite(contact.email);
    final RenderBox box = context.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    // Show near center of screen for touch friendliness
    final center = box.localToGlobal(
        Offset(box.size.width / 2, box.size.height / 2),
        ancestor: overlay);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        center.dx - 120,
        center.dy - 20,
        center.dx + 120,
        center.dy + 20,
      ),
      color: const Color(0xFFF5F8FB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFF8AAFC8), width: 1.5),
      ),
      elevation: 8,
      items: [
        PopupMenuItem<String>(
          value: 'fav',
          height: 40,
          child: Row(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isFav
                    ? const Color(0xFFFFF3D0)
                    : const Color(0xFFE8F0F6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isFav
                      ? const Color(0xFFD4A017)
                      : const Color(0xFFAAC5DB),
                ),
              ),
              child: Icon(
                isFav ? Icons.star : Icons.star_border,
                size: 14,
                color: isFav
                    ? const Color(0xFFD4A017)
                    : const Color(0xFF6A8FB5),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isFav ? 'Remove from Favorites' : 'Add to Favorites',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1B2A38),
                fontFamilyFallback: ['Segoe UI', 'Tahoma'],
              ),
            ),
          ]),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'remove',
          height: 40,
          child: Row(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFFDE8E8),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD04040)),
              ),
              child: const Icon(Icons.person_remove,
                  size: 13, color: Color(0xFFD04040)),
            ),
            const SizedBox(width: 10),
            const Text(
              'Remove Contact',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1B2A38),
                fontFamilyFallback: ['Segoe UI', 'Tahoma'],
              ),
            ),
          ]),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'profile',
          height: 36,
          child: Row(children: [
            const SizedBox(width: 4),
            const Icon(Icons.person_outline, size: 16, color: Color(0xFF6A8FB5)),
            const SizedBox(width: 10),
            Text(
              stripWlmColorTags(contact.displayName),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF5A7A94),
                fontStyle: FontStyle.italic,
                fontFamilyFallback: ['Segoe UI', 'Tahoma'],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
          enabled: false,
        ),
      ],
    ).then((value) {
      if (value == 'fav') {
        notifier.toggleFavorite(contact.email);
      } else if (value == 'remove') {
        _confirmRemoveContact(contact);
      }
    });
  }

  void _confirmRemoveContact(Contact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF0F4F8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFF7A9BB5)),
        ),
        title: const Text(
          'Remove Contact',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF243E57),
            fontFamilyFallback: ['Segoe UI', 'Tahoma'],
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${stripWlmColorTags(contact.displayName)} (${contact.email}) from your contact list?',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF3B5A7C),
            fontFamilyFallback: ['Segoe UI', 'Tahoma'],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(msnpClientProvider).removeContact(contact.email);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${contact.email} removed.')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD04040)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
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
      onLongPress: () => _showContactMenu(contact),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        child: Row(children: [
          // ── Avatar ──
          SizedBox(
            width: 38,
            height: 38,
            child: Stack(clipBehavior: Clip.none, children: [
              // Photo — inset ~15.5% to sit inside the aero frame center
              Positioned(
                top: 6, left: 6, right: 6, bottom: 6,
                child: Opacity(
                  opacity: online ? 1 : 0.45,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: _contactAvatarImg(contact, online: online),
                  ),
                ),
              ),
              // Aero glass frame, recolored by status via ColorFilter
              Positioned.fill(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    online
                        ? _statusAccent(contact.status).withValues(alpha: 0.85)
                        : const Color(0xFF9EACB8).withValues(alpha: 0.45),
                    BlendMode.srcATop,
                  ),
                  child: Opacity(
                    opacity: online ? 1 : 0.7,
                    child: Image.asset(_assetAvatarFrame, fit: BoxFit.fill),
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
  //  DISPLAY PICTURE PICKER
  // ═════════════════════════════════════════════════════════════════════════

  /// Resize arbitrary image bytes to 96×96 PNG using dart:ui (no extra deps).
  Future<Uint8List?> _resizeImageTo96x96(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 96,
        targetHeight: 96,
      );
      final frame = await codec.getNextFrame();
      final img = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 96, 96));
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        const Rect.fromLTWH(0, 0, 96, 96),
        Paint(),
      );
      final picture = recorder.endRecording();
      final rendered = await picture.toImage(96, 96);
      final pngData =
          await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (pngData == null) return null;
      return pngData.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Delete old avatar files for this email so they don't accumulate.
  Future<void> _cleanupOldAvatars(Directory dir, String email) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.contains('avatar_$email')) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  void _showDisplayPicturePicker() {
    // Default WLM 2009 usertiles extracted from usertiles.mct.
    final defaultTiles = <String>[
      'basketball.png', 'bonsai.png', 'chef.png', 'chess.png',
      'daisy.png', 'doctor.png', 'dog.png', 'electric_guitar.png',
      'executive.png', 'fish.png', 'flare.png', 'gerber_daisy.png',
      'golf.png', 'guest.png', 'guitar.png', 'kitten.png',
      'leaf.png', 'morty.png', 'music.png', 'robot.png',
      'seastar.png', 'shopping.png', 'sports.png', 'surf.png',
      'tennis.png',
    ];

    // WLM 2009 "Dynamic Display Pictures" (animated GIFs).
    final dynamicTiles = <String>[
      'fall.gif', 'spring.gif', 'summer.gif', 'winter.gif', 'soccer.gif',
    ];

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
            width: 420,
            height: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title bar
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
                    'Change Display Picture',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Current avatar preview
                Consumer(builder: (_, cRef, __) {
                  final avatarPath = cRef.watch(profileAvatarProvider);
                  return SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 12, left: 12, right: 12, bottom: 12,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: avatarPath != null && File(avatarPath).existsSync()
                                ? Image.file(File(avatarPath), fit: BoxFit.cover)
                                : Image.asset(_assetAvatarUser, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned.fill(
                          child: Image.asset(_assetAvatarFrame, fit: BoxFit.fill),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Choose a default picture or browse for your own:',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2A3E50),
                      fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // ── Default + Dynamic usertile grid ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFB0C4D8)),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(6),
                        children: [
                          // ── Static Display Pictures ──
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                            ),
                            itemCount: defaultTiles.length,
                            itemBuilder: (context, index) {
                              final tile = defaultTiles[index];
                              return GestureDetector(
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  final data = await DefaultAssetBundle.of(context)
                                      .load('assets/images/usertiles/$tile');
                                  final client = ref.read(msnpClientProvider);
                                  final appDir =
                                      await getApplicationDocumentsDirectory();
                                  final ts = DateTime.now().millisecondsSinceEpoch;
                                  await _cleanupOldAvatars(appDir, client.selfEmail);
                                  final destFile = File(
                                      '${appDir.path}/avatar_${client.selfEmail}_$ts.png');
                                  await destFile.writeAsBytes(
                                      data.buffer.asUint8List());
                                  ref
                                      .read(profileAvatarProvider.notifier)
                                      .setPath(destFile.path);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: const Color(0xFFD0D0D0)),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: Image.asset(
                                        'assets/images/usertiles/$tile',
                                        fit: BoxFit.cover),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          // ── Dynamic Display Pictures (animated GIFs) ──
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Dynamic Display Pictures',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2A3E50),
                                fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                              ),
                            ),
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                            ),
                            itemCount: dynamicTiles.length,
                            itemBuilder: (context, index) {
                              final tile = dynamicTiles[index];
                              return GestureDetector(
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  final data = await DefaultAssetBundle.of(context)
                                      .load('assets/images/usertiles/$tile');
                                  final client = ref.read(msnpClientProvider);
                                  final appDir =
                                      await getApplicationDocumentsDirectory();
                                  final ts = DateTime.now().millisecondsSinceEpoch;
                                  await _cleanupOldAvatars(appDir, client.selfEmail);
                                  final ext = tile.split('.').last;
                                  final destFile = File(
                                      '${appDir.path}/avatar_${client.selfEmail}_$ts.$ext');
                                  await destFile.writeAsBytes(
                                      data.buffer.asUint8List());
                                  ref
                                      .read(profileAvatarProvider.notifier)
                                      .setPath(destFile.path);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: const Color(0xFFD0D0D0)),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: Image.asset(
                                        'assets/images/usertiles/$tile',
                                        fit: BoxFit.cover),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // ── Buttons: Browse / Cancel ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _wlmDialogButton('Browse...', () async {
                        Navigator.pop(ctx);
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                        );
                        if (result == null || result.files.isEmpty) return;
                        final path = result.files.single.path;
                        if (path == null) return;
                        final srcBytes = await File(path).readAsBytes();
                        debugPrint('[DP-Browse] Source: $path  '
                            '${srcBytes.length} bytes');
                        // Resize to 96×96 PNG for WLM 2009 compatibility.
                        // If resize fails, fall back to the original file.
                        final resized = await _resizeImageTo96x96(srcBytes);
                        debugPrint('[DP-Browse] Resize result: '
                            '${resized != null ? '${resized.length} bytes' : 'FAILED (using original)'}');
                        final client = ref.read(msnpClientProvider);
                        final appDir =
                            await getApplicationDocumentsDirectory();
                        final ts = DateTime.now().millisecondsSinceEpoch;
                        await _cleanupOldAvatars(appDir, client.selfEmail);
                        final ext = path.split('.').last.toLowerCase();
                        final destExt = resized != null ? 'png' : ext;
                        final destFile = File(
                            '${appDir.path}/avatar_${client.selfEmail}_$ts.$destExt');
                        if (resized != null) {
                          await destFile.writeAsBytes(resized);
                        } else {
                          await File(path).copy(destFile.path);
                        }
                        debugPrint('[DP-Browse] Saved: ${destFile.path}  '
                            '${await destFile.length()} bytes');
                        ref
                            .read(profileAvatarProvider.notifier)
                            .setPath(destFile.path);
                      }),
                      const SizedBox(width: 6),
                      _wlmDialogButton('Cancel', () {
                        Navigator.pop(ctx);
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  SCENE PICKER
  // ═════════════════════════════════════════════════════════════════════════
  void _showScenePicker() {
    // All 22 WLM 2009 scenes extracted from scenes.mct (content.xml order).
    final scenes = <_WlmScene>[
      _WlmScene('Daisy Hill', '0001.png'),
      _WlmScene('Bamboo', '0002.jpg'),
      _WlmScene('Cherry Blossoms', '0003.jpg'),
      _WlmScene('Violet Springtime', '0004.png'),
      _WlmScene('Flourish', '0005.png'),
      _WlmScene('Dawn', '0006.png'),
      _WlmScene('Field', '0007.png'),
      _WlmScene('Mesmerizing Brown', '0008.png'),
      _WlmScene('Butterfly Pattern', 'ButterflyPattern.png'),
      _WlmScene('Carbon Fiber', 'CarbonFiber.jpg'),
      _WlmScene('Dottie Green', 'DottieGreen.png'),
      _WlmScene('Graffiti', 'Graffiti.jpg'),
      _WlmScene('Mesmerizing White', 'MesmerizingWhite.png'),
      _WlmScene('Morty', 'Morty.png'),
      _WlmScene('Robot', 'Robot.jpg'),
      _WlmScene('Silhouette', 'Silhouette.jpg'),
      _WlmScene('Zune 01', 'zune_01.jpg'),
      _WlmScene('Zune 02', 'zune_02.jpg'),
      _WlmScene('Zune 03', 'zune_03.jpg'),
      _WlmScene('Zune 04', 'zune_04.jpg'),
      _WlmScene('Zune 05', 'zune_05.jpg'),
      _WlmScene('Zune 06', 'zune_06.jpg'),
    ];

    // WLM 2009 colour scheme presets – negative packed 24-bit RGB.
    final colorPresets = <_ScenePreset>[
      _ScenePreset('Default', '-1', const Color(0xFF5B9BD5)),
      _ScenePreset('Red', '-65536', const Color(0xFFFF0000)),
      _ScenePreset('Orange', '-33024', const Color(0xFFFF7F00)),
      _ScenePreset('Yellow', '-256', const Color(0xFFFFFF00)),
      _ScenePreset('Green', '-16744448', const Color(0xFF008000)),
      _ScenePreset('Teal', '-16744320', const Color(0xFF008080)),
      _ScenePreset('Blue', '-16776961', const Color(0xFF0000FF)),
      _ScenePreset('Purple', '-8388480', const Color(0xFF800080)),
      _ScenePreset('Pink', '-16181', const Color(0xFFFFC0CB)),
      _ScenePreset('Brown', '-5952982', const Color(0xFFA5682A)),
      _ScenePreset('Grey', '-8355712', const Color(0xFF808080)),
      _ScenePreset('Black', '-16777216', const Color(0xFF000000)),
    ];

    final client = ref.read(msnpClientProvider);
    String selectedScene = client.selfScene;
    String selectedScheme = client.selfColorScheme;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFFF0F4F8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Color(0xFF7A9BB5)),
              ),
              child: SizedBox(
                width: 440,
                height: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title bar ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
                        'Change Scene',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ── Section: Scenes ──
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Choose a scene:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2A3E50),
                          fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // ── Scene thumbnail grid (scrollable, 4 columns) ──
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFB0C4D8)),
                          ),
                          child: GridView.builder(
                            padding: const EdgeInsets.all(6),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              childAspectRatio: 2.0, // 640x320 = 2:1
                            ),
                            itemCount: scenes.length + 1, // +1 for "Default"
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // Default (no scene)
                                final isSelected = selectedScene.isEmpty;
                                return GestureDetector(
                                  onTap: () {
                                    setDialogState(
                                        () => selectedScene = '');
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF87CEEB),
                                          Color(0xFFB0E0B0)
                                        ],
                                      ),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF2060A0)
                                            : const Color(0xFFC0C0C0),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text('Default',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF2A3E50),
                                          fontFamilyFallback: [
                                            'Segoe UI',
                                            'Tahoma'
                                          ],
                                        )),
                                  ),
                                );
                              }
                              final scene = scenes[index - 1];
                              final isSelected =
                                  selectedScene == scene.file;
                              return GestureDetector(
                                onTap: () {
                                  setDialogState(
                                      () => selectedScene = scene.file);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF2060A0)
                                          : const Color(0xFFC0C0C0),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Image.asset(
                                    'assets/images/scenes/${scene.file}',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // ── Section: Colour scheme ──
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Choose a colour for your scene:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2A3E50),
                          fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // ── Colour scheme squares ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: colorPresets.map((preset) {
                          final isSelected =
                              preset.value == selectedScheme;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(
                                  () => selectedScheme = preset.value);
                            },
                            child: Tooltip(
                              message: preset.label,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: preset.color,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF1A4A7A)
                                        : const Color(0xFFB0B0B0),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 16)
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── Buttons: OK / Cancel / Apply ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _wlmDialogButton('OK', () {
                            client.setScene(selectedScene);
                            client.setColorScheme(selectedScheme);
                            Navigator.pop(ctx);
                          }),
                          const SizedBox(width: 6),
                          _wlmDialogButton('Cancel', () {
                            Navigator.pop(ctx);
                          }),
                          const SizedBox(width: 6),
                          _wlmDialogButton('Apply', () {
                            client.setScene(selectedScene);
                            client.setColorScheme(selectedScheme);
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// WLM 2009 styled dialog button.
  Widget _wlmDialogButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0F4F8), Color(0xFFD8E4EE)],
          ),
          border: Border.all(color: const Color(0xFF8AA8C0)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1A3A50),
              fontFamilyFallback: ['Segoe UI', 'Tahoma'],
            )),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  DISPLAY NAME CHANGE
  // ═════════════════════════════════════════════════════════════════════════
  void _showChangeDisplayNameDialog() {
    final client = ref.read(msnpClientProvider);
    final controller = TextEditingController(text: client.selfDisplayName);

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
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title bar
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
                    'Change Display Name',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 128,
                    decoration: InputDecoration(
                      labelText: 'Display name',
                      labelStyle: const TextStyle(
                        color: Color(0xFF4A6A84),
                        fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: const BorderSide(color: Color(0xFF3678B0), width: 2),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                    ),
                    onSubmitted: (val) {
                      final name = val.trim();
                      if (name.isNotEmpty) {
                        client.setDisplayName(name);
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel',
                            style: TextStyle(color: Color(0xFF4A6A84))),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3678B0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        onPressed: () {
                          final name = controller.text.trim();
                          if (name.isNotEmpty) {
                            client.setDisplayName(name);
                          }
                          Navigator.pop(ctx);
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
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
        child: const SizedBox.shrink(),
    );
  }
}

/// Simple data holder for scene color presets.
class _ScenePreset {
  const _ScenePreset(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
}

/// WLM 2009 scene entry (filename inside assets/images/scenes/).
class _WlmScene {
  const _WlmScene(this.displayName, this.file);
  final String displayName;
  final String file;
}
