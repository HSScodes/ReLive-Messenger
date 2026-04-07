import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/server_config.dart';
import '../../network/msnp_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';
import '../../services/sound_service.dart';
import '../main_window/main_window.dart';
import 'connecting_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
{
  static const String _assetBottomGlassBar =
    'assets/images/extracted/msgsres/carved_png_436872.png';
  static const String _assetHelpIcon =
    'assets/images/extracted/msgsres/carved_png_9727920.png';
  static const String _assetDropdownArrow =
    'assets/images/extracted/msgsres/carved_png_10968848.png';
  static const String _assetAvatarFrame =
    'assets/images/extracted/aeroframe_transparent.png';
  static const String _assetAvatarUser =
    'assets/images/extracted/default_avatar_hd.png';
  static const String _assetCheckboxOff =
    'assets/images/extracted/msgsres/carved_png_9797544.png';
  static const String _assetCheckboxOn =
    'assets/images/extracted/msgsres/carved_png_10738400.png';

  static const List<String> _emailHistory = <String>[
    'example555@hotmail.com',
    'account.live@example.com',
  ];

  static const List<_StatusOption> _statusItems = <_StatusOption>[
    _StatusOption(
      value: 'Online',
      iconAsset: 'assets/images/extracted/msgsres/carved_png_9375216.png',
    ),
    _StatusOption(
      value: 'Busy',
      iconAsset: 'assets/images/extracted/msgsres/carved_png_9387680.png',
    ),
    _StatusOption(
      value: 'Away',
      iconAsset: 'assets/images/extracted/msgsres/carved_png_9380960.png',
    ),
    _StatusOption(
      value: 'Appear offline',
      iconAsset: 'assets/images/extracted/msgsres/carved_png_9394296.png',
    ),
  ];

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _rememberPassword = false;
  bool _autoSignIn = false;
  bool _obscurePassword = true;
  String _selectedStatus = 'Online';
  bool _navigatedToMain = false;

  static const _keyRememberMe = 'wlm_remember_me';
  static const _keyRememberPw = 'wlm_remember_password';
  static const _keyAutoSignIn = 'wlm_auto_sign_in';
  static const _keySavedEmail = 'wlm_saved_email';
  static const _keySavedPw = 'wlm_saved_password';

  @override
  void initState() {
    super.initState();
    _emailController.text = ServerConfig.devPrefillEmail;
    _passwordController.text = ServerConfig.devPrefillPassword;
    _rememberMe = true;
    _rememberPassword = true;
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRememberMe = prefs.getBool(_keyRememberMe) ?? false;
    final savedRememberPw = prefs.getBool(_keyRememberPw) ?? false;
    final savedAutoSignIn = prefs.getBool(_keyAutoSignIn) ?? false;
    final savedEmail = prefs.getString(_keySavedEmail);
    final savedPw = prefs.getString(_keySavedPw);

    if (!mounted) return;
    setState(() {
      _rememberMe = savedRememberMe;
      _rememberPassword = savedRememberPw;
      _autoSignIn = savedAutoSignIn;
      if (savedRememberMe && savedEmail != null && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
      }
      if (savedRememberPw && savedPw != null && savedPw.isNotEmpty) {
        _passwordController.text = savedPw;
      }
    });

    // Auto sign-in if credentials are present
    if (savedAutoSignIn &&
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onSignIn();
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, _rememberMe);
    await prefs.setBool(_keyRememberPw, _rememberPassword);
    await prefs.setBool(_keyAutoSignIn, _autoSignIn);
    if (_rememberMe) {
      await prefs.setString(_keySavedEmail, _emailController.text.trim());
    } else {
      await prefs.remove(_keySavedEmail);
    }
    if (_rememberPassword) {
      await prefs.setString(_keySavedPw, _passwordController.text);
    } else {
      await prefs.remove(_keySavedPw);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    await _savePreferences();
    final authNotifier = ref.read(authProvider.notifier);
    // Navigate to connecting screen immediately
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConnectingScreen()),
    );
    await authNotifier.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      ticket: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(connectionProvider, (_, next) {
      next.whenData((status) {
        if (status == ConnectionStatus.connected && !_navigatedToMain) {
          _navigatedToMain = true;
          const SoundService().playOnline();
          // Pop connecting screen + push main window, replacing all routes
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainWindowScreen()),
            (_) => false,
          );
        } else if (status == ConnectionStatus.error && !_navigatedToMain) {
          // Pop back to the login screen on error
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      });
    });

    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFD0E4F0),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final pageHeight = constraints.maxHeight < 720 ? 720.0 : constraints.maxHeight;

          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.0),
            ),
            child: SingleChildScrollView(
              child: SizedBox(
                width: constraints.maxWidth,
                height: pageHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF53B8EA),
                              Color(0xFF7ECDF2),
                              Color(0xFFB0DFF5),
                              Color(0xFFDBEFF8),
                            ],
                            stops: [0.0, 0.18, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 56,
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
                          border: Border(top: BorderSide(color: Color(0x33FFFFFF), width: 1)),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 56,
                      left: 0,
                      right: 0,
                      bottom: 45,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 370),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.55),
                                  Colors.white.withOpacity(0.40),
                                  Colors.white.withOpacity(0.50),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.65),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1A4978).withOpacity(0.12),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                              Center(
                                child: SizedBox(
                                  width: 160,
                                  height: 160,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned(
                                        top: 25, left: 25, right: 20, bottom: 20,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.asset(_assetAvatarUser, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Image.asset(_assetAvatarFrame, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _emailComboField(),
                              const SizedBox(height: 8),
                              _classicTextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                hintText: 'Enter your password',
                                showDropArrow: false,
                                suffixWidget: GestureDetector(
                                  onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(0, 6, 6, 6),
                                    child: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                      size: 18,
                                      color: const Color(0xFF5D6C76),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Text(
                                    'Sign in as:',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF1D2A33),
                                      fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: _statusDropdown()),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _classicCheckbox(
                                value: _rememberMe,
                                label: 'Remember me',
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                              ),
                              _classicCheckbox(
                                value: _rememberPassword,
                                label: 'Remember my password',
                                onChanged: (value) {
                                  setState(() {
                                    _rememberPassword = value ?? false;
                                  });
                                },
                              ),
                              _classicCheckbox(
                                value: _autoSignIn,
                                label: 'Sign me in automatically',
                                onChanged: (value) {
                                  setState(() {
                                    _autoSignIn = value ?? false;
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                              Center(
                                child: SizedBox(
                                  width: 148,
                                  height: 40,
                                  child: ElevatedButton(
                                    onPressed: authState.isLoading ? null : _onSignIn,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3A8CC4),
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shadowColor: const Color(0xFF1A4978).withOpacity(0.3),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
                                      ),
                                    ),
                                    child: authState.isLoading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Text('Sign in'),
                                  ),
                                ),
                              ),
                              if (authState.error != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  authState.error!
                                      .replaceAll('CrossTalk', 'server')
                                      .replaceAll('crosstalk', 'server')
                                      .replaceAll('Microsoft', '')
                                      .replaceAll('microsoft', ''),
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF9A2525)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _footerBar(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emailComboField() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB0C8D8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1C2A35),
                fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                hintText: 'example555@hotmail.com',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF5D6C76),
                  fontStyle: FontStyle.italic,
                  fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
                ),
              ),
              cursorColor: const Color(0xFF356C8F),
            ),
          ),
          Container(
            width: 26,
            height: double.infinity,
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Color(0xFFBFD0DC))),
            ),
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              tooltip: '',
              onSelected: (value) {
                setState(() {
                  _emailController.text = value;
                });
              },
              itemBuilder: (_) {
                return _emailHistory
                    .map(
                      (email) => PopupMenuItem<String>(
                        value: email,
                        height: 28,
                        child: Text(
                          email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1D2A33),
                            fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
                          ),
                        ),
                      ),
                    )
                    .toList();
              },
              icon: Image.asset(_assetDropdownArrow, width: 16, height: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusDropdown() {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB0C8D8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _statusItems.any((option) => option.value == _selectedStatus)
              ? _selectedStatus
              : _statusItems.first.value,
          icon: Image.asset(_assetDropdownArrow, width: 16, height: 16),
          iconSize: 16,
          dropdownColor: const Color(0xFFF3F7FA),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1D2A33),
            fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
          ),
          items: _statusItems
              .map(
                (status) => DropdownMenuItem<String>(
                  value: status.value,
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Image.asset(status.iconAsset, width: 16, height: 16, filterQuality: FilterQuality.none),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          status.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _selectedStatus = value;
            });
          },
        ),
      ),
    );
  }

  Widget _footerBar() {
    return Container(
      height: 42,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.25),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Privacy statement',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF1A5C8A),
              fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 14, color: const Color(0xFF97AAB6)),
          const SizedBox(width: 10),
          const Text(
            'Server status',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF1A5C8A),
              fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _classicTextField({
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? hintText,
    bool showDropArrow = false,
    Widget? suffixWidget,
  }) {
    return SizedBox(
      height: 34,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF1C2A35),
          fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          hintText: hintText,
          hintStyle: const TextStyle(
            fontSize: 15,
            color: Color(0xFF5D6C76),
            fontStyle: FontStyle.italic,
            fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
          ),
          suffixIcon: suffixWidget ??
              (showDropArrow
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 6, 8),
                      child: Image.asset(_assetDropdownArrow, width: 16, height: 16),
                    )
                  : null),
          fillColor: Colors.white,
          filled: true,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFB0C8D8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF5E8FB3)),
          ),
        ),
        cursorColor: const Color(0xFF356C8F),
      ),
    );
  }

  Widget _classicCheckbox({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          InkWell(
            onTap: () => onChanged(!value),
            child: SizedBox(
              width: 16,
              height: 16,
              child: value
                  ? Image.asset(_assetCheckboxOn, fit: BoxFit.fill)
                  : Image.asset(_assetCheckboxOff, fit: BoxFit.fill),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2E3E45),
              fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusOption {
  const _StatusOption({
    required this.value,
    required this.iconAsset,
  });

  final String value;
  final String iconAsset;
}
