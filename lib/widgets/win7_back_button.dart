import 'package:flutter/material.dart';

/// Windows 7 File Explorer circular back button.
///
/// Uses the AI-generated replacement asset which already points left.
class Win7BackButton extends StatelessWidget {
  const Win7BackButton({super.key, required this.onPressed, this.size = 28});

  static const String _assetPath =
      'assets/images/extracted/msgsres/carved_png_10983152.png';

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Image.asset(
        _assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
