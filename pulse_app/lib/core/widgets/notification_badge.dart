import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../features/notifications/notification_screen.dart';

class NotificationBadge extends StatefulWidget {
  final String userId;
  const NotificationBadge({super.key, required this.userId});

  @override
  State<NotificationBadge> createState() =>
    _NotificationBadgeState();
}

class _NotificationBadgeState
    extends State<NotificationBadge> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final results = await Future.wait([
        ApiClient.dio.get('/notifications/${widget.userId}'),
        ApiClient.dio.get('/chat/unread/${widget.userId}'),
      ]);
      final notifCount = results[0].data['unread_count'] as int? ?? 0;
      final chatCount  = results[1].data['unread_count'] as int? ?? 0;
      if (mounted) {
        setState(() { _unread = notifCount + chatCount; });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationScreen(
              userId: widget.userId),
          ),
        );
        _loadCount();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: Colors.white, size: 20),
          ),
          if (_unread > 0)
            Positioned(
              top: -4, right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _unread > 9 ? '9+' : '$_unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  )),
              ),
            ),
        ],
      ),
    );
  }
}