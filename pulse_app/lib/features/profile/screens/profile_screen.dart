import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/ruler_picker.dart';
import 'specialist_list_screen.dart';
import '../../auth/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final Map? profile;
  const ProfileScreen({
    super.key,
    required this.userId,
    this.profile,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map? _user;
  Map? _profile;
  bool _isLoading  = true;
  bool _isSaving   = false;
  int  _waterTarget = 2500;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _logout() {
    ApiClient.dio.options.headers.remove('Authorization');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _loadData() async {
  try {
    final userRes = await ApiClient.dio.get(
      '/auth/user/${widget.userId}',
    );
    final profileRes = await ApiClient.dio.get(
      '/profile/${widget.userId}',
    );
    setState(() {
      _user      = userRes.data['user'];
      _profile   = Map<String, dynamic>.from(
        profileRes.data['profile'] ?? {});
      _isLoading = false;
    });
  } catch (e) {
    setState(() { _isLoading = false; });
  }
}

  Future<void> _editOption({
    required String title,
    required List<Map<String, String>> options,
    required String currentValue,
    required Function(String) onSave,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        title: Text(title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) {
            final isSelected = opt['value'] == currentValue;
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                onSave(opt['value']!);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                    ? AppTheme.primary.withOpacity(0.1)
                    : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                      ? AppTheme.primary
                      : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(opt['label']!,
                        style: TextStyle(
                          fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                          color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textDark,
                        )),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle,
                        color: AppTheme.primary, size: 20),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

 Future<void> _saveProfile(
    Map<String, dynamic> updates) async {
  if (_profile == null) return;
  setState(() { _isSaving = true; });
  try {
    // Fusionner les updates avec le profil actuel
    final updatedProfile = {
      ..._profile!,
      ...updates,
    };

    // Envoyer au backend — le BMR sera recalculé automatiquement
    final response = await ApiClient.dio.post(
      '/profile',
      data: {
        'user_id':        widget.userId,
        'age':            updatedProfile['age'],
        'gender':         updatedProfile['gender'],
        'height_cm':      double.tryParse(
          updatedProfile['height_cm']?.toString() ?? '0'),
        'current_weight': double.tryParse(
          updatedProfile['current_weight']?.toString() ?? '0'),
        'target_weight':  double.tryParse(
          updatedProfile['target_weight']?.toString() ?? '0'),
        'activity_level': updatedProfile['activity_level'],
        'goal':           updatedProfile['goal'],
      },
    );

    // Mettre à jour le profil local avec les nouvelles valeurs
    // incluant le nouveau BMR et daily_calories
    setState(() {
      _profile   = Map<String, dynamic>.from(
        response.data['profile'] ?? {});
      _isSaving  = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle,
                color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Profil mis à jour ! '
                  'Nouvelles calories : '
                  '${double.tryParse(_profile!['daily_calories']
                    ?.toString() ?? '0')?.toInt() ?? 0} kcal/jour',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
    setState(() { _isSaving = false; });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary))
          : Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Profil',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        )),
                      Row(
                        children: [
                          if (_isSaving)
                            const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primary,
                              ),
                            ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                size: 18,
                                color: AppTheme.textDark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16),
                    child: Column(
                      children: [

                        // Avatar + nom
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: AppTheme.primary,
                                child: Text(
                                  (_user?['full_name'] ?? 'U')[0]
                                    .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _user?['full_name']
                                  ?? 'Utilisateur',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _user?['email'] ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textGray,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Stats rapides
                        Row(
                          children: [
                            _buildStatCard(
                              '${_profile?['current_weight']
                                ?.toString().split('.')[0]
                                ?? '--'} kg',
                              'Poids actuel',
                              Icons.monitor_weight_outlined,
                              Colors.blue,
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              '${_profile?['target_weight']
                                ?.toString().split('.')[0]
                                ?? '--'} kg',
                              'Objectif',
                              Icons.flag_outlined,
                              AppTheme.primary,
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              '${_profile?['daily_calories']
                                ?.toString().split('.')[0]
                                ?? '--'}',
                              'kcal/jour',
                              Icons.local_fire_department_outlined,
                              Colors.orange,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Mes objectifs
                        _buildSectionTitle('Mes objectifs'),
                        _buildSection([
                          _buildEditableRow(
                            icon: Icons.water_drop,
                            iconColor: const Color(0xFF3B82F6),
                            label: 'Hydratation',
                            value: '$_waterTarget ml',
                            onTap: () => showRulerPicker(
                              context: context,
                              title: 'Objectif hydratation',
                              subtitle: 'Restez hydraté pour '
                                'de meilleures performances',
                              initialValue:
                                _waterTarget.toDouble(),
                              minValue: 500,
                              maxValue: 5000,
                              step: 250,
                              unit: 'ml',
                              onDone: (val) => setState(() =>
                                _waterTarget = val.toInt()),
                            ),
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildEditableRow(
                            icon: Icons.local_fire_department,
                            iconColor: const Color(0xFFFF5C5C),
                            label: 'Objectif calorique',
                            value: '${_profile?['daily_calories']
                              ?.toString().split('.')[0]
                              ?? '--'} kcal',
                            onTap: () {},
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildEditableRow(
                            icon: Icons.track_changes,
                            iconColor: const Color(0xFFEF4444),
                            label: 'Objectif principal',
                            value: _goalLabel(_profile?['goal']),
                            onTap: () => _editOption(
                              title: 'Objectif principal',
                              currentValue:
                                _profile?['goal'] ?? '',
                              options: [
                                {
                                  'value': 'lose',
                                  'label': 'Perdre du poids',
                                },
                                {
                                  'value': 'maintain',
                                  'label': 'Maintenir mon poids',
                                },
                                {
                                  'value': 'gain',
                                  'label': 'Prendre de la masse',
                                },
                              ],
                              onSave: (val) =>
                                _saveProfile({'goal': val}),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 16),

                        // Mon corps
                        _buildSectionTitle('Mon corps'),
                        _buildSection([
                          _buildEditableRow(
                            icon: Icons.height,
                            iconColor: const Color(0xFFF59E0B),
                            label: 'Taille',
                            value: '${_profile?['height_cm']
                              ?.toString().split('.')[0]
                              ?? '--'} cm',
                            onTap: () => showRulerPicker(
                              context: context,
                              title: 'Quelle est votre taille ?',
                              subtitle: 'Votre taille nous aide '
                                'à calculer vos besoins',
                              initialValue: double.tryParse(
                                _profile?['height_cm']
                                  ?.toString() ?? '170')
                                ?? 170,
                              minValue: 100,
                              maxValue: 220,
                              unit: 'cm',
                              onDone: (val) =>
                                _saveProfile({'height_cm': val}),
                            ),
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildEditableRow(
                            icon: Icons.monitor_weight_outlined,
                            iconColor: const Color(0xFF3B82F6),
                            label: 'Poids actuel',
                            value: '${_profile?['current_weight']
                              ?.toString().split('.')[0]
                              ?? '--'} kg',
                            onTap: () => showRulerPicker(
                              context: context,
                              title: 'Quel est votre poids ?',
                              subtitle: 'Votre poids actuel pour '
                                'calculer vos besoins',
                              initialValue: double.tryParse(
                                _profile?['current_weight']
                                  ?.toString() ?? '70')
                                ?? 70,
                              minValue: 30,
                              maxValue: 200,
                              unit: 'kg',
                              onDone: (val) => _saveProfile(
                                {'current_weight': val}),
                            ),
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildEditableRow(
                            icon: Icons.flag_outlined,
                            iconColor: const Color(0xFF10B981),
                            label: 'Poids cible',
                            value: '${_profile?['target_weight']
                              ?.toString().split('.')[0]
                              ?? '--'} kg',
                            onTap: () => showRulerPicker(
                              context: context,
                              title: 'Quel est votre objectif ?',
                              subtitle: 'Votre poids cible pour '
                                'suivre votre progression',
                              initialValue: double.tryParse(
                                _profile?['target_weight']
                                  ?.toString() ?? '65')
                                ?? 65,
                              minValue: 30,
                              maxValue: 200,
                              unit: 'kg',
                              onDone: (val) => _saveProfile(
                                {'target_weight': val}),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 16),

                        // Mon mode de vie
                        _buildSectionTitle('Mon mode de vie'),
                        _buildSection([
                          _buildEditableRow(
                            icon: Icons.directions_run,
                            iconColor: const Color(0xFF8B5CF6),
                            label: 'Niveau d\'activité',
                            value: _activityLabel(
                              _profile?['activity_level']),
                            onTap: () => _editOption(
                              title: 'Niveau d\'activité',
                              currentValue:
                                _profile?['activity_level'] ?? '',
                              options: [
                                {
                                  'value': 'sedentary',
                                  'label': 'Sédentaire',
                                },
                                {
                                  'value': 'light',
                                  'label': 'Légèrement actif',
                                },
                                {
                                  'value': 'moderate',
                                  'label': 'Modérément actif',
                                },
                                {
                                  'value': 'active',
                                  'label': 'Très actif',
                                },
                                {
                                  'value': 'very_active',
                                  'label': 'Extrêmement actif',
                                },
                              ],
                              onSave: (val) => _saveProfile(
                                {'activity_level': val}),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 16),

                        // Informations
                        _buildSectionTitle('Informations'),
                        _buildSection([
                          _buildReadOnlyRow(
                            icon: Icons.person,
                            iconColor: const Color(0xFF3B82F6),
                            label: 'Genre',
                            value: _profile?['gender'] == 'male'
                              ? 'Homme' : 'Femme',
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildReadOnlyRow(
                            icon: Icons.cake,
                            iconColor: const Color(0xFFEF4444),
                            label: 'Âge',
                            value:
                              '${_profile?['age'] ?? '--'} ans',
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildReadOnlyRow(
                            icon: Icons.egg_alt_outlined,
                            iconColor: Colors.green,
                            label: 'Protéines',
                            value:
                              '${_profile?['protein_g']
                                ?.toString().split('.')[0]
                                ?? '--'} g/jour',
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildReadOnlyRow(
                            icon: Icons.grain,
                            iconColor: Colors.orange,
                            label: 'Glucides',
                            value:
                              '${_profile?['carbs_g']
                                ?.toString().split('.')[0]
                                ?? '--'} g/jour',
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildReadOnlyRow(
                            icon: Icons.water_drop_outlined,
                            iconColor: Colors.red,
                            label: 'Lipides',
                            value:
                              '${_profile?['fat_g']
                                ?.toString().split('.')[0]
                                ?? '--'} g/jour',
                          ),
                        ]),

                        const SizedBox(height: 16),

                        // Mon médecin / coach
                        _buildSectionTitle('Mon médecin / coach'),
                        _buildSection([
                          _buildEditableRow(
                            icon: Icons.person_search_outlined,
                            iconColor: const Color(0xFF6366F1),
                            label: 'Trouver un spécialiste',
                            value: '',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SpecialistListScreen(
                                  patientId: widget.userId,
                                ),
                              ),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 16),

                        // Se déconnecter
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextButton.icon(
                            onPressed: _logout,
                            icon: const Icon(
                              Icons.logout,
                              color: Colors.red,
                              size: 18,
                            ),
                            label: const Text(
                              'Se déconnecter',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Supprimer compte
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Supprimer le compte',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textGray,
          )),
      ),
    );
  }

  Widget _buildSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildEditableRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textDark,
                )),
            ),
            Text(value,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textGray,
              )),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
              color: AppTheme.textGray, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
              color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textDark,
              )),
          ),
          Text(value,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textGray,
            )),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label,
      IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              )),
            Text(label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textGray,
              )),
          ],
        ),
      ),
    );
  }

  String _activityLabel(String? level) {
    switch (level) {
      case 'sedentary':   return 'Sédentaire';
      case 'light':       return 'Léger';
      case 'moderate':    return 'Modéré';
      case 'active':      return 'Actif';
      case 'very_active': return 'Très actif';
      default:            return '--';
    }
  }

  String _goalLabel(String? goal) {
    switch (goal) {
      case 'lose':     return 'Perdre du poids';
      case 'gain':     return 'Prendre de la masse';
      case 'maintain': return 'Maintenir';
      default:         return '--';
    }
  }
}