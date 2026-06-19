import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class ScoreScreen extends StatefulWidget {
  final String userId;
  const ScoreScreen({super.key, required this.userId});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  Map?  _todayScore;
  List  _history    = [];
  bool  _isLoading  = true;
  bool  _isCalculating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final historyRes = await ApiClient.dio.get(
        '/scores/history/${widget.userId}',
      );
      final scores = historyRes.data['scores'] as List;

      // Le score du jour est le premier de la liste
      final today = DateTime.now().toIso8601String().split('T')[0];
      Map? todayScore;
      for (final s in scores) {
        final d = s['score_date']?.toString().split('T')[0];
        if (d == today) { todayScore = s; break; }
      }

      setState(() {
        _todayScore = todayScore;
        _history    = scores;
        _isLoading  = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _calculateScore() async {
    setState(() { _isCalculating = true; });
    try {
      final res = await ApiClient.dio.post(
        '/scores/calculate',
        data: { 'user_id': widget.userId },
      );
      setState(() {
        _todayScore  = res.data['score'];
        _isCalculating = false;
      });
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Score calculé !'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      setState(() { _isCalculating = false; });
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
    return 'À améliorer';
  }

  String _scoreEmoji(double score) {
    if (score >= 90) return '🏆';
    if (score >= 70) return '👍';
    return '💪';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Score du jour'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _isCalculating ? null : _calculateScore,
            icon: _isCalculating
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ))
              : const Icon(Icons.refresh,
                  color: AppTheme.primary),
            label: const Text('Calculer',
              style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(
            color: AppTheme.primary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                // Score du jour
                _todayScore != null
                  ? _buildTodayScore()
                  : _buildNoScore(),

                const SizedBox(height: 20),

                // Historique 7 jours
                if (_history.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Historique des 7 derniers jours',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      )),
                  ),
                  const SizedBox(height: 12),
                  _buildHistory(),
                ],
              ],
            ),
          ),
    );
  }

  Widget _buildNoScore() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('🎯',
            style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text('Pas encore de score aujourd\'hui',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            )),
          const SizedBox(height: 8),
          const Text(
            'Enregistrez vos repas puis calculez\nvotre score de discipline',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textGray)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isCalculating ? null : _calculateScore,
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Calculer mon score'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayScore() {
    final score = double.tryParse(
      _todayScore!['total_score']?.toString() ?? '0') ?? 0;
    final color = _scoreColor(score);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [

          // Score principal
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_scoreEmoji(score),
                style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: score.toInt().toString(),
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const TextSpan(
                          text: ' /100',
                          style: TextStyle(
                            fontSize: 20,
                            color: AppTheme.textGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _scoreLabel(score),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Barre de progression
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 12,
            ),
          ),

          const SizedBox(height: 24),

          // Détail des 2 composantes principales
          Row(
            children: [
              _buildScoreItem(
                'Calories',
                double.tryParse(_todayScore!['calories_score']
                  ?.toString() ?? '0') ?? 0,
                50,
                Colors.orange,
                Icons.local_fire_department,
              ),
              _buildScoreItem(
                'Macros',
                (double.tryParse(_todayScore!['protein_score']
                  ?.toString() ?? '0') ?? 0) +
                (double.tryParse(_todayScore!['carbs_score']
                  ?.toString() ?? '0') ?? 0) +
                (double.tryParse(_todayScore!['fat_score']
                  ?.toString() ?? '0') ?? 0),
                50,
                Colors.blue,
                Icons.pie_chart,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Détail des 3 macros individuelles
          _buildMacroRow(
            'Protéines',
            double.tryParse(_todayScore!['protein_score']
              ?.toString() ?? '0') ?? 0,
            17,
            Colors.green,
          ),
          const SizedBox(height: 8),
          _buildMacroRow(
            'Glucides',
            double.tryParse(_todayScore!['carbs_score']
              ?.toString() ?? '0') ?? 0,
            17,
            Colors.orange,
          ),
          const SizedBox(height: 8),
          _buildMacroRow(
            'Lipides',
            double.tryParse(_todayScore!['fat_score']
              ?.toString() ?? '0') ?? 0,
            16,
            Colors.red,
          ),

          const SizedBox(height: 20),

          // Streak
          if ((_todayScore!['streak_days'] ?? 0) > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔥',
                    style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    '${_todayScore!['streak_days']} jours '
                    'consécutifs !',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreItem(String label, double value,
      int max, Color color, IconData icon) {
    final pct = value / max;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            '${value.toInt()}/$max',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textGray,
            )),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow(String label, double value, int max, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textGray,
              )),
            Text(
              '${value.toInt()}/$max',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              )),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: max > 0 ? (value / max).clamp(0.0, 1.0) : 0,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: _history.take(7).map((score) {
          final s = double.tryParse(
            score['total_score']?.toString() ?? '0') ?? 0;
          final color = _scoreColor(s);
          final date  = score['score_date']?.toString()
            .split('T')[0] ?? '';
          final parts = date.split('-');
          final label = parts.length == 3
            ? '${parts[2]}/${parts[1]}'
            : date;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: s / 100,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${s.toInt()}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    )),
                ),
                const SizedBox(width: 4),
                Text(_scoreEmoji(s),
                  style: const TextStyle(fontSize: 14)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}