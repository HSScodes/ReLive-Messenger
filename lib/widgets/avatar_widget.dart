import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/presence_status.dart';

/// WLM 2009-style avatar: photo (or placeholder) beneath the Aero glass frame,
/// with the frame tinted by [status] via [ColorFilter].
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.status,
    this.imagePath,
    this.size = 38,
  });

  final PresenceStatus status;
  final String? imagePath;
  final double size;

  static const _assetFrame =
      'assets/images/extracted/msgsres/carved_png_9812096.png';
  static const _assetPlaceholder =
      'assets/images/extracted/msgsres/carved_png_9801032.png';

  @override
  Widget build(BuildContext context) {
    final online = status != PresenceStatus.appearOffline;
    final tint = _tintForStatus(status);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        // Photo / placeholder layer – inset ~15.5% so the photo sits
        // inside the frame's transparent center (original ratio 96/139).
        Positioned(
          top: size * 0.155, left: size * 0.155,
          right: size * 0.155, bottom: size * 0.155,
          child: Opacity(
            opacity: online ? 1.0 : 0.45,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.06),
              child: _buildPhoto(),
            ),
          ),
        ),
        // Aero glass frame, recolored by status
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              tint.withValues(alpha: 0.85),
              BlendMode.srcATop,
            ),
            child: Opacity(
              opacity: online ? 1.0 : 0.7,
              child: Image.asset(_assetFrame, fit: BoxFit.fill),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildPhoto() {
    final path = imagePath;
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Image.asset(_assetPlaceholder, fit: BoxFit.cover),
      );
    }
    return Image.asset(_assetPlaceholder, fit: BoxFit.cover);
  }

  Color _tintForStatus(PresenceStatus s) {
    switch (s) {
      case PresenceStatus.online:
        return const Color(0xFF39FF14);
      case PresenceStatus.away:
        return const Color(0xFFE2C92D);
      case PresenceStatus.busy:
        return const Color(0xFFD94A4A);
      case PresenceStatus.appearOffline:
        return const Color(0xFF9EACB8);
    }
  }
}
