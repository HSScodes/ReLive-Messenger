import 'package:flutter/material.dart';

import '../utils/presence_status.dart';
import 'status_indicator.dart';

class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.initials,
    required this.status,
    this.size = 48,
  });

  final String initials;
  final PresenceStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEAF8FF), Color(0xFFBFE7FF)],
            ),
            border: Border.all(
              color: const Color(0xFFFFFFFF),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x44000000), blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2A4E6F),
              fontSize: size * 0.3,
            ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: StatusIndicator(status: status, size: size * 0.28),
        ),
      ],
    );
  }
}
