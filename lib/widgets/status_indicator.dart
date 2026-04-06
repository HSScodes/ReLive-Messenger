import 'package:flutter/material.dart';

import '../utils/presence_status.dart';

class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    super.key,
    required this.status,
    this.size = 12,
  });

  final PresenceStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _colorForStatus(status),
        border: Border.all(color: Colors.white, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: _colorForStatus(status).withValues(alpha: 0.5),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }

  Color _colorForStatus(PresenceStatus value) {
    switch (value) {
      case PresenceStatus.online:
        return const Color(0xFF2FD050);
      case PresenceStatus.busy:
        return const Color(0xFFE53835);
      case PresenceStatus.away:
        return const Color(0xFFF4A23C);
      case PresenceStatus.appearOffline:
        return const Color(0xFF9AA4B5);
    }
  }
}
