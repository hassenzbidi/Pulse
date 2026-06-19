import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../chat/screens/discussion_screen.dart';
import '../../stats/screens/stats_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String doctorId;
  const PatientDetailScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
  });

  @override
  State<PatientDetailScreen> createState() =>
    _PatientDetailScreenState();
}

class _PatientDetailScreenState
    extends State<PatientDetailScreen> {
  Map?      _data;
  List      _comments     = [];
  bool      _isLoading    = true;
  DateTime  _selectedDate = DateTime.now();
  final     _commentCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

  String get _dateLabel {
    final now = DateTime.now();
    if (_selectedDate.year  == now.year  &&
        _selectedDate.month == now.month &&
        _selectedDate.day   == now.day) return "Aujourd'hui";
    final diff = now.difference(_selectedDate).inDays;
    if (diff == 1) return 'Hier';
    const months = [
      'jan','fév','mar','avr','mai','juin',
      'juil','août','sep','oct','nov','déc',
    ];
    return '${_selectedDate.day} '
           '${months[_selectedDate.month - 1]}';
  }

  Future<void> _showCalendar() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() { _selectedDate = picked; });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      final dashRes = await ApiClient.dio.get(
        '/doctor/patient/${widget.patientId}/dashboard',
        queryParameters: {
          'doctor_id': widget.doctorId,
          'date':      _formatDate(_selectedDate),
        },
      );
      final commRes = await ApiClient.dio.get(
        '/doctor/comments/${widget.patientId}',
      );
      setState(() {
        _data      = dashRes.data;
        _comments  = commRes.data['comments'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _addComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ApiClient.dio.post('/doctor/comment', data: {
        'doctor_id':  widget.doctorId,
        'patient_id': widget.patientId,
        'content':    text,
      });
      _commentCtrl.clear();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commentaire ajouté !'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Color _scoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  String _scoreLabel(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 70) return 'Bon';
    return 'A améliorer';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(widget.patientName),
        backgroundColor: const Color(0xFF1A2E2A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DiscussionScreen(
                    currentUserId: widget.doctorId,
                    otherUserId:   widget.patientId,
                    otherName:     widget.patientName,
                    otherRole:     'patient',
                  ),
                ),
              ),
              backgroundColor: AppTheme.primary,
              tooltip: 'Envoyer un message',
              child: const Icon(
                Icons.message_outlined,
                color: Colors.white,
              ),
            ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(
            color: AppTheme.primary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPatientHeader(),
                const SizedBox(height: 12),
                _buildNutritionCard(),
                const SizedBox(height: 12),
                _buildScoresCard(),
                const SizedBox(height: 12),
                _buildWeightCard(),
                const SizedBox(height: 12),
                _buildMealsCard(),
                const SizedBox(height: 12),
                _buildCommentsCard(),
                const SizedBox(height: 32),
              ],
            ),
          ),
    );
  }

  Widget _buildPatientHeader() {
    final user    = _data?['user'];
    final profile = _data?['profile'];
    if (user == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            child: Text(
              (user['full_name'] ?? 'P')[0].toUpperCase(),
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['full_name'] ?? 'Patient',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  )),
                Text(user['email'] ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textGray,
                  )),
                if (profile != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _infoChip(
                        '${profile['age'] ?? '--'} ans',
                        Icons.cake_outlined,
                        Colors.purple,
                      ),
                      const SizedBox(width: 6),
                      _infoChip(
                        profile['gender'] == 'male'
                          ? 'Homme' : 'Femme',
                        Icons.person_outlined,
                        Colors.blue,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StatsScreen(
                        userId:   widget.patientId,
                        isDoctor: true,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bar_chart_outlined,
                          size: 14, color: AppTheme.primary),
                        SizedBox(width: 6),
                        Text('Voir les graphiques',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            )),
        ],
      ),
    );
  }

  Widget _buildNutritionCard() {
    final p = _data?['profile'];
    if (p == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Objectifs nutritionnels',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            )),
          const SizedBox(height: 12),
          Row(
            children: [
              _nutritionItem('Calories',
                '${double.tryParse(p['daily_calories']?.toString() ?? '0')?.toInt() ?? 0} kcal',
                Colors.orange),
              _nutritionItem('Protéines',
                '${double.tryParse(p['protein_g']?.toString() ?? '0')?.toInt() ?? 0} g',
                Colors.blue),
              _nutritionItem('Glucides',
                '${double.tryParse(p['carbs_g']?.toString() ?? '0')?.toInt() ?? 0} g',
                Colors.green),
              _nutritionItem('Lipides',
                '${double.tryParse(p['fat_g']?.toString() ?? '0')?.toInt() ?? 0} g',
                Colors.red),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoRow('Poids actuel',
                  '${double.tryParse(p['current_weight']?.toString() ?? '0')?.toInt() ?? 0} kg'),
              ),
              Expanded(
                child: _infoRow('Poids cible',
                  '${double.tryParse(p['target_weight']?.toString() ?? '0')?.toInt() ?? 0} kg'),
              ),
              Expanded(
                child: _infoRow('Objectif',
                  p['goal'] == 'lose' ? 'Perte'
                    : p['goal'] == 'gain' ? 'Masse'
                    : 'Maintien'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nutritionItem(String label, String value,
      Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            )),
          Text(label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textGray,
            )),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textGray,
          )),
        Text(value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          )),
      ],
    );
  }

  Widget _buildScoresCard() {
    final scores = _data?['scores'] as List? ?? [];
    if (scores.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scores de discipline (7 derniers jours)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            )),
          const SizedBox(height: 12),
          ...scores.take(7).map((s) {
            final score = double.tryParse(
              s['total_score']?.toString() ?? '0') ?? 0;
            final color = _scoreColor(score);
            final date  = s['score_date']
              ?.toString().split('T')[0] ?? '';
            final parts = date.split('-');
            final label = parts.length == 3
              ? '${parts[2]}/${parts[1]}' : date;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGray,
                      )),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: score / 100,
                        backgroundColor: color.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${score.toInt()}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    )),
                  const SizedBox(width: 4),
                  Text(_scoreLabel(score),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGray,
                    )),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeightCard() {
    final weights = _data?['weights'] as List? ?? [];
    if (weights.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Historique poids',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            )),
          const SizedBox(height: 12),
          ...weights.take(5).map((w) {
            final weight = double.tryParse(
              w['weight_kg']?.toString() ?? '0') ?? 0;
            final date = w['logged_at']
              ?.toString().split('T')[0] ?? '';
            final parts = date.split('-');
            final label = parts.length == 3
              ? '${parts[2]}/${parts[1]}/${parts[0].substring(2)}'
              : date;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textGray,
                    )),
                  Text('${weight.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    )),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMealsCard() {
    final meals   = _data?['meals'] as List? ?? [];
    final profile = _data?['profile'];
    final totalTarget = profile != null
      ? (double.tryParse(
          profile['daily_calories']?.toString() ?? '0') ?? 2000.0)
      : 2000.0;

    final mealDefs = [
      {
        'type':  'breakfast',
        'label': 'Petit-déjeuner',
        'icon':  Icons.wb_sunny_outlined,
        'color': Colors.orange,
        'pct':   0.25,
      },
      {
        'type':  'lunch',
        'label': 'Déjeuner',
        'icon':  Icons.lunch_dining_outlined,
        'color': Colors.green,
        'pct':   0.35,
      },
      {
        'type':  'dinner',
        'label': 'Dîner',
        'icon':  Icons.dinner_dining_outlined,
        'color': Colors.indigo,
        'pct':   0.30,
      },
      {
        'type':  'snack',
        'label': 'Snacks',
        'icon':  Icons.apple_outlined,
        'color': Colors.red,
        'pct':   0.10,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec date et bouton calendrier
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Repas — $_dateLabel',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              GestureDetector(
                onTap: _showCalendar,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today,
                        size: 14, color: AppTheme.primary),
                      SizedBox(width: 6),
                      Text('Changer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primary,
                        )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Grille 2×2 par type de repas
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.3,
              ),
            itemCount: mealDefs.length,
            itemBuilder: (_, i) {
              final mt     = mealDefs[i];
              final type   = mt['type']  as String;
              final color  = mt['color'] as Color;
              final label  = mt['label'] as String;
              final icon   = mt['icon']  as IconData;
              final target =
                (totalTarget * (mt['pct'] as double)).toInt();
              final cal    = meals
                .where((m) => m['meal_type'] == type)
                .fold<double>(0, (s, m) => s +
                  (double.tryParse(
                    m['total_cal']?.toString() ?? '0') ?? 0));
              final pct    = target > 0
                ? (cal / target).clamp(0.0, 1.0)
                : 0.0;
              final over   = cal > target && target > 0;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: over
                    ? Border.all(
                        color: Colors.red.shade200, width: 1.5)
                    : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const Spacer(),
                    Text(label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textDark,
                      )),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor:
                          color.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(
                          over ? Colors.red : color),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cal > 0
                        ? '${cal.toInt()} / $target kcal'
                        : 'Aucun repas',
                      style: TextStyle(
                        fontSize: 10,
                        color: over
                          ? Colors.red
                          : AppTheme.textGray,
                        fontWeight: over
                          ? FontWeight.w600
                          : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mes commentaires',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            )),
          const SizedBox(height: 12),

          // Ajouter commentaire
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ajouter un commentaire...',
                    hintStyle: const TextStyle(
                      color: AppTheme.textGray,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  ),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addComment,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send,
                    color: Colors.white, size: 18),
                ),
              ),
            ],
          ),

          if (_comments.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ..._comments.map((c) => _buildCommentItem(c)),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map comment) {
    final date = comment['created_at']
      ?.toString().split('T')[0] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                comment['doctor_name'] ?? 'Dr.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                )),
              Text(date,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textGray,
                )),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            comment['content'] ?? '',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textDark,
            )),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }
}