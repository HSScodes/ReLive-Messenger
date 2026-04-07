import 'package:flutter/material.dart';

/// Connecting splash screen with animated rotating 3D buddy.
class ConnectingScreen extends StatefulWidget {
  const ConnectingScreen({super.key, this.statusText = 'Connecting...'});

  final String statusText;

  @override
  State<ConnectingScreen> createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends State<ConnectingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const int _frameCount = 36;
  static const List<String> _frames = [
    'assets/images/extracted/login_anim/frame_000.png',
    'assets/images/extracted/login_anim/frame_001.png',
    'assets/images/extracted/login_anim/frame_002.png',
    'assets/images/extracted/login_anim/frame_003.png',
    'assets/images/extracted/login_anim/frame_004.png',
    'assets/images/extracted/login_anim/frame_005.png',
    'assets/images/extracted/login_anim/frame_006.png',
    'assets/images/extracted/login_anim/frame_007.png',
    'assets/images/extracted/login_anim/frame_008.png',
    'assets/images/extracted/login_anim/frame_009.png',
    'assets/images/extracted/login_anim/frame_010.png',
    'assets/images/extracted/login_anim/frame_011.png',
    'assets/images/extracted/login_anim/frame_012.png',
    'assets/images/extracted/login_anim/frame_013.png',
    'assets/images/extracted/login_anim/frame_014.png',
    'assets/images/extracted/login_anim/frame_015.png',
    'assets/images/extracted/login_anim/frame_016.png',
    'assets/images/extracted/login_anim/frame_017.png',
    'assets/images/extracted/login_anim/frame_018.png',
    'assets/images/extracted/login_anim/frame_019.png',
    'assets/images/extracted/login_anim/frame_020.png',
    'assets/images/extracted/login_anim/frame_021.png',
    'assets/images/extracted/login_anim/frame_022.png',
    'assets/images/extracted/login_anim/frame_023.png',
    'assets/images/extracted/login_anim/frame_024.png',
    'assets/images/extracted/login_anim/frame_025.png',
    'assets/images/extracted/login_anim/frame_026.png',
    'assets/images/extracted/login_anim/frame_027.png',
    'assets/images/extracted/login_anim/frame_028.png',
    'assets/images/extracted/login_anim/frame_029.png',
    'assets/images/extracted/login_anim/frame_030.png',
    'assets/images/extracted/login_anim/frame_031.png',
    'assets/images/extracted/login_anim/frame_032.png',
    'assets/images/extracted/login_anim/frame_033.png',
    'assets/images/extracted/login_anim/frame_034.png',
    'assets/images/extracted/login_anim/frame_035.png',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache all frames for smooth playback
    for (final path in _frames) {
      precacheImage(AssetImage(path), context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
              Color(0xFF53B8EA),
              Color(0xFF7ECDF2),
              Color(0xFFB0DFF5),
              Color(0xFFDBEFF8),
            ],
            stops: [0.0, 0.18, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              // 3D rotating buddy animation
              SizedBox(
                width: 120,
                height: 120,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final frameIndex =
                        (_controller.value * _frameCount).floor() % _frameCount;
                    return Image.asset(
                      _frames[frameIndex],
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
              // Status text
              Text(
                widget.statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
                  shadows: [
                    Shadow(color: Color(0x55000000), blurRadius: 6),
                  ],
                ),
              ),
              const Spacer(flex: 5),
            ],
          ),
        ),
      ),
    );
  }
}
