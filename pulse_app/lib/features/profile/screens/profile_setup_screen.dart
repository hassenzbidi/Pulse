import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../dashboard/screens/dashboard_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String userId;
  const ProfileSetupScreen({super.key, required this.userId});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _ageController    = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetController = TextEditingController();

  String _gender        = 'male';
  String _activityLevel = 'moderate';
  String _goal          = 'lose';
  bool   _isLoading     = false;
  String? _error;
  int _currentStep      = 0;

  Future<void> _saveProfile() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      final response = await ApiClient.dio.post(
        '/profile',
        data: {
          'user_id':        widget.userId,
          'age':            int.parse(_ageController.text),
          'gender':         _gender,
          'height_cm':      double.parse(_heightController.text),
          'current_weight': double.parse(_weightController.text),
          'target_weight':  double.parse(_targetController.text),
          'activity_level': _activityLevel,
          'goal':           _goal,
        },
      );

      if (response.statusCode == 200 && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(userId: widget.userId),
          ),
        );
      }
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data['error'] ?? 'Erreur lors de la sauvegarde';
      });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vos informations',
          style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        const Text('Pour calculer vos besoins caloriques',
          style: TextStyle(color: AppTheme.textGray)),
        const SizedBox(height: 32),

        TextField(
          controller: _ageController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Âge',
            prefixIcon: Icon(Icons.cake_outlined),
            suffixText: 'ans',
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _heightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Taille',
            prefixIcon: Icon(Icons.height),
            suffixText: 'cm',
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _weightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Poids actuel',
            prefixIcon: Icon(Icons.monitor_weight_outlined),
            suffixText: 'kg',
          ),
        ),
        const SizedBox(height: 24),

        const Text('Genre',
          style: TextStyle(fontWeight: FontWeight.w600,
            color: AppTheme.textDark)),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _gender = 'male'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _gender == 'male'
                      ? AppTheme.primary
                      : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _gender == 'male'
                        ? AppTheme.primary
                        : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.male,
                        color: _gender == 'male'
                          ? Colors.white
                          : AppTheme.textGray),
                      const SizedBox(height: 4),
                      Text('Homme',
                        style: TextStyle(
                          color: _gender == 'male'
                            ? Colors.white
                            : AppTheme.textGray,
                          fontWeight: FontWeight.w500,
                        )),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _gender = 'female'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _gender == 'female'
                      ? AppTheme.primary
                      : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _gender == 'female'
                        ? AppTheme.primary
                        : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.female,
                        color: _gender == 'female'
                          ? Colors.white
                          : AppTheme.textGray),
                      const SizedBox(height: 4),
                      Text('Femme',
                        style: TextStyle(
                          color: _gender == 'female'
                            ? Colors.white
                            : AppTheme.textGray,
                          fontWeight: FontWeight.w500,
                        )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Votre objectif',
          style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        const Text('Que voulez-vous accomplir ?',
          style: TextStyle(color: AppTheme.textGray)),
        const SizedBox(height: 32),

        TextField(
          controller: _targetController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Poids cible',
            prefixIcon: Icon(Icons.flag_outlined),
            suffixText: 'kg',
          ),
        ),
        const SizedBox(height: 24),

        const Text('Objectif principal',
          style: TextStyle(fontWeight: FontWeight.w600,
            color: AppTheme.textDark)),
        const SizedBox(height: 12),

        _buildGoalCard('lose',     'Perdre du poids',    Icons.trending_down),
        const SizedBox(height: 8),
        _buildGoalCard('gain',     'Prendre de la masse', Icons.trending_up),
        const SizedBox(height: 8),
        _buildGoalCard('maintain', 'Maintenir mon poids', Icons.trending_flat),

        const SizedBox(height: 24),

        const Text('Niveau d\'activité',
          style: TextStyle(fontWeight: FontWeight.w600,
            color: AppTheme.textDark)),
        const SizedBox(height: 12),

        _buildActivityCard('sedentary',   'Sédentaire',     'Peu ou pas d\'exercice'),
        const SizedBox(height: 8),
        _buildActivityCard('moderate',    'Modéré',         'Exercice 3-5 fois/semaine'),
        const SizedBox(height: 8),
        _buildActivityCard('very_active', 'Très actif',     'Exercice intense quotidien'),
      ],
    );
  }

  Widget _buildGoalCard(String value, String label, IconData icon) {
    final isSelected = _goal == value;
    return GestureDetector(
      onTap: () => setState(() => _goal = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
            ? AppTheme.primary.withOpacity(0.1)
            : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
              ? AppTheme.primary
              : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
              color: isSelected ? AppTheme.primary : AppTheme.textGray),
            const SizedBox(width: 12),
            Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.textDark,
              )),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle,
                color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(String value, String label, String subtitle) {
    final isSelected = _activityLevel == value;
    return GestureDetector(
      onTap: () => setState(() => _activityLevel = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
            ? AppTheme.primary.withOpacity(0.1)
            : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
              ? AppTheme.primary
              : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isSelected
                        ? AppTheme.primary
                        : AppTheme.textDark,
                    )),
                  Text(subtitle,
                    style: const TextStyle(
                      fontSize: 12, color: AppTheme.textGray)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Étape ${_currentStep + 1} / 2'),
        backgroundColor: AppTheme.background,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barre de progression
            LinearProgressIndicator(
              value: (_currentStep + 1) / 2,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _currentStep == 0 ? _buildStep1() : _buildStep2(),

                    const SizedBox(height: 24),

                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_error!,
                          style: const TextStyle(color: AppTheme.error)),
                      ),

                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: _isLoading ? null : () {
                        if (_currentStep == 0) {
                          setState(() => _currentStep = 1);
                        } else {
                          _saveProfile();
                        }
                      },
                      child: _isLoading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                        : Text(_currentStep == 0
                            ? 'Continuer'
                            : 'Terminer la configuration'),
                    ),

                    if (_currentStep == 1) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() => _currentStep = 0),
                        child: const Text('Retour',
                          style: TextStyle(color: AppTheme.textGray)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetController.dispose();
    super.dispose();
  }
}