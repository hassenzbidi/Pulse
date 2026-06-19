import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MealsScreen extends StatelessWidget {
  final String userId;
  const MealsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Journal alimentaire'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_outlined,
              size: 64, color: AppTheme.textGray),
            SizedBox(height: 16),
            Text('Journal alimentaire',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              )),
            SizedBox(height: 8),
            Text('Bientôt disponible',
              style: TextStyle(color: AppTheme.textGray)),
          ],
        ),
      ),
    );
  }
}