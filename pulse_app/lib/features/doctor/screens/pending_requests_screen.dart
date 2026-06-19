import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PendingRequestsScreen extends StatelessWidget {
  final List requests;
  final Function(String, String) onRespond;
  const PendingRequestsScreen({
    super.key,
    required this.requests,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes en attente'),
        backgroundColor: const Color(0xFF1A2E2A),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (_, i) {
          final req = requests[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                    AppTheme.primary.withOpacity(0.1),
                  child: Text(
                    (req['full_name'] ?? 'P')[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req['full_name'] ?? 'Patient',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                      Text(req['email'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGray)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle,
                        color: AppTheme.primary),
                      onPressed: () =>
                        onRespond(req['id'], 'approved'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel,
                        color: Colors.red),
                      onPressed: () =>
                        onRespond(req['id'], 'rejected'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}