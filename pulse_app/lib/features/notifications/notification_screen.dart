import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/api/api_client.dart';

class NotificationScreen extends StatefulWidget {
  final String userId;
  const NotificationScreen({
    super.key, required this.userId});

  @override
  State<NotificationScreen> createState() =>
    _NotificationScreenState();
}

class _NotificationScreenState
    extends State<NotificationScreen> {
  List _notifications = [];
  bool _isLoading     = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final res = await ApiClient.dio.get(
        '/notifications/${widget.userId}',
      );
      setState(() {
        _notifications =
          res.data['notifications'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ApiClient.dio.patch(
        '/notifications/read-all/${widget.userId}',
      );
      await _loadNotifications();
    } catch (_) {}
  }

  Future<void> _markRead(String id) async {
    try {
      await ApiClient.dio.patch(
        '/notifications/$id/read',
      );
    } catch (_) {}
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'access_request':  return Icons.person_add_outlined;
      case 'access_approved': return Icons.check_circle_outline;
      case 'access_rejected': return Icons.cancel_outlined;
      default:                return Icons.notifications_outlined;
    }
  }

  Color _getColor(String? type) {
    switch (type) {
      case 'access_request':  return Colors.orange;
      case 'access_approved': return Colors.green;
      case 'access_rejected': return Colors.red;
      default:                return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF1A2E2A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_notifications.any((n) => !n['is_read']))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Tout lire',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                )),
            ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(
            color: AppTheme.primary))
        : _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                    size: 64, color: AppTheme.textGray),
                  SizedBox(height: 12),
                  Text('Aucune notification',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textGray,
                    )),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _notifications.length,
              itemBuilder: (_, i) {
                final n = _notifications[i];
                final isRead = n['is_read'] == true;
                final type   = n['type'];
                final color  = _getColor(type);
                final date   = n['created_at']
                  ?.toString().split('T')[0] ?? '';

                return GestureDetector(
                  onTap: () async {
                    if (!isRead) {
                      await _markRead(n['id']);
                      await _loadNotifications();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(
                      bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRead
                        ? Colors.white
                        : color.withOpacity(0.05),
                      borderRadius:
                        BorderRadius.circular(12),
                      border: isRead
                        ? null
                        : Border.all(
                            color: color.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment:
                        CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_getIcon(type),
                            color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                              CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                  MainAxisAlignment
                                    .spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      n['title'] ?? '',
                                      style: TextStyle(
                                        fontWeight: isRead
                                          ? FontWeight.w500
                                          : FontWeight.bold,
                                        fontSize: 14,
                                        color:
                                          AppTheme.textDark,
                                      )),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n['message'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textGray,
                                )),
                              const SizedBox(height: 6),
                              Text(date,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textGray,
                                )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}