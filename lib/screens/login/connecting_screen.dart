import 'dart:async';
import 'package:flutter/material.dart';

/// WLM 2009 "Connecting…" splash screen.
///
/// Shows the animated buddy sprite sheet (`carved_png_9543256.png`, 1536×36)
/// and the Windows Live Messenger logo (`carved_png_10810632.png`) at the
/// bottom.
class ConnectingScreen extends StatefulWidget {
  const ConnectingScreen({super.key, this.statusText = 'Connecting...'});

  final String statusText;

  @override
  State<ConnectingScreen> createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends State<ConnectingScreen> {
  static const _spriteAsset =
      'assets/images/extracted/msgsres/carved_png_9543256.png';
  static const _logoAsset =
      'assets/images/extracted/msgsres/carved_png_10810632.png';

  // Sprite sheet is 1536×36. Each frame is 48×36 → 32 frames.
  static const int _frameCount = 32;
  static const double _frameWidth = 48;
  static const double _frameHeight = 36;

  int _currentFrame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      setState(() {
        _currentFrame = (_currentFrame + 1) % _frameCount;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1D6DB8),
              Color(0xFF3A8FD4),
              Color(0xFF5BAEE0),
              Color(0xFFBEDDF2),
            ],
            stops: [0.0, 0.35, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              // Animated buddy sprite
              SizedBox(
                width: _frameWidth * 1.5,
                height: _frameHeight * 1.5,
                child: ClipRect(
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    alignment: Alignment.topLeft,
                    child: Transform.translate(
                      offset: Offset(-_currentFrame * _frameWidth * 1.5, 0),
                      child: Image.asset(
                        _spriteAsset,
                        height: _frameHeight * 1.5,
                        fit: BoxFit.fitHeight,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Status text
              Text(
                widget.statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
                  shadows: [
                    Shadow(color: Color(0x88000000), blurRadius: 4),
                  ],
                ),
              ),
              const Spacer(flex: 4),
              // WLM Logo at bottom
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Image.asset(
                  _logoAsset,
                  width: 200,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
