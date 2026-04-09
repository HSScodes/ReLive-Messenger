import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/update_service.dart';

/// About / credits page for reLive Messenger alpha.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _assetAvatar = 'assets/images/HSScodes.png';
  static const _assetFrame =
      'assets/images/app/ui/carved_png_9812096.png';
  static const _githubUrl = 'https://github.com/HSScodes';

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
              Color(0xFF3A7BD5), // WLM-style blue top
              Color(0xFF1E3A5F), // Deep navy bottom
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar with back button ───────────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── Avatar with green aero frame ──────────────────────────
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  children: [
                    // Photo inset (9.35 % border like AvatarWidget)
                    Positioned(
                      top: 140 * 0.0935,
                      left: 140 * 0.0935,
                      right: 140 * 0.0935,
                      bottom: 140 * 0.0935,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(140 * 0.04),
                        child: Image.asset(_assetAvatar, fit: BoxFit.cover),
                      ),
                    ),
                    // Aero frame, green-tinted
                    Positioned.fill(
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          const Color(0xFF39FF14).withValues(alpha: 0.35),
                          BlendMode.srcATop,
                        ),
                        child: Image.asset(_assetFrame, fit: BoxFit.fill),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── App name ──────────────────────────────────────────────
              const Text(
                'reLive Messenger',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamilyFallback: ['Segoe UI', 'Tahoma'],
                  letterSpacing: 0.5,
                  shadows: [Shadow(color: Color(0x66000000), blurRadius: 6)],
                ),
              ),

              const SizedBox(height: 6),

              // ── Version ───────────────────────────────────────────────
              FutureBuilder<String>(
                future: UpdateService.currentVersion(),
                builder: (context, snap) {
                  final ver = snap.data ?? '...';
                  return Text(
                    'v$ver',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.65),
                      fontFamilyFallback: const ['Segoe UI', 'Tahoma'],
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // ── Tagline ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Coded with nostalgia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.55,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontStyle: FontStyle.italic,
                    fontFamilyFallback: const ['Segoe UI', 'Tahoma'],
                    shadows: const [
                      Shadow(color: Color(0x33000000), blurRadius: 4),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Developer credit ──────────────────────────────────────
              Text(
                'by HSScodes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontFamilyFallback: const ['Segoe UI', 'Tahoma'],
                ),
              ),

              const SizedBox(height: 16),

              // ── GitHub link button ────────────────────────────────────
              GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse(_githubUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.code,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'GitHub',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontFamilyFallback: const ['Segoe UI', 'Tahoma'],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // ── Footer ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'This project is not affiliated with Crosstalk or Microsoft.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                    fontFamilyFallback: const ['Segoe UI', 'Tahoma'],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
