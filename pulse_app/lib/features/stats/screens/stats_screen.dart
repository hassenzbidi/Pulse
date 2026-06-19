import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/ruler_picker.dart';

class StatsScreen extends StatefulWidget {
  final String userId;
  final bool isDoctor;

  const StatsScreen({
    super.key,
    required this.userId,
    this.isDoctor = false,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  List  _weightLogs   = [];
  List  _scoreLogs    = [];
  List<Map<String, dynamic>> _waterLogs = [];
  Map?  _profile;

  bool _weightLoading = true;
  bool _scoreLoading  = true;
  bool _waterLoading  = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadWeight();
    _loadScores();
    _loadWater();
    _loadProfile();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadWeight() async {
    try {
      final res = await ApiClient.dio.get(
        '/weight/history/${widget.userId}',
      );
      if (!mounted) return;
      setState(() {
        _weightLogs   = res.data['weight_logs'] as List? ?? [];
        _weightLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _weightLoading = false);
    }
  }

  Future<void> _loadScores() async {
    try {
      final res = await ApiClient.dio.get(
        '/scores/history/${widget.userId}',
      );
      if (!mounted) return;
      setState(() {
        _scoreLogs    = res.data['scores'] as List? ?? [];
        _scoreLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _scoreLoading = false);
    }
  }

  Future<void> _loadWater() async {
    try {
      final now = DateTime.now();
      final futures = List.generate(7, (i) async {
        final d = now.subtract(Duration(days: i));
        try {
          final r = await ApiClient.dio.get(
            '/weight/water/${widget.userId}',
            queryParameters: {'date': _fmtDate(d)},
          );
          return {
            'date':      _fmtDate(d),
            'amount_ml': (r.data['amount_ml'] as num?)?.toInt() ?? 0,
          };
        } catch (_) {
          return {'date': _fmtDate(d), 'amount_ml': 0};
        }
      });
      final raw = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        _waterLogs    = raw.reversed
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _waterLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _waterLoading = false);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiClient.dio.get('/profile/${widget.userId}');
      if (!mounted) return;
      setState(() => _profile = res.data['profile'] as Map?);
    } catch (_) {}
  }

  Future<void> _addWeightLog(double weight) async {
    try {
      await ApiClient.dio.post('/weight', data: {
        'user_id':   widget.userId,
        'weight_kg': weight,
      });
      await _loadWeight();
      await _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Color _scoreColor(double s) {
    if (s >= 90) return Colors.green;
    if (s >= 70) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Statistiques'),
        backgroundColor: const Color(0xFF1A2E2A),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Poids'),
            Tab(text: 'Score'),
            Tab(text: 'Hydratation'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildWeightTab(),
          _buildScoreTab(),
          _buildWaterTab(),
        ],
      ),
    );
  }

  // ─── ONGLET POIDS ──────────────────────────────────────────────────

  Widget _buildWeightTab() {
    if (_weightLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    final sorted = [..._weightLogs]..sort((a, b) {
        final da = (a['logged_at'] ?? a['created_at'])
            ?.toString() ?? '';
        final db = (b['logged_at'] ?? b['created_at'])
            ?.toString() ?? '';
        return da.compareTo(db);
      });

    final logs = sorted.length > 30
        ? sorted.sublist(sorted.length - 30)
        : sorted;

    if (logs.isEmpty) {
      return _emptyState(
        'Aucune pesée enregistrée',
        Icons.monitor_weight_outlined,
        showAddButton: !widget.isDoctor,
        onAdd: _openWeightPicker,
      );
    }

    final spots = <FlSpot>[
      for (int i = 0; i < logs.length; i++)
        FlSpot(
          i.toDouble(),
          double.tryParse(
              logs[i]['weight_kg']?.toString() ?? '0') ??
              0,
        ),
    ];

    final ys     = spots.map((s) => s.y).toList();
    final minY   = (ys.reduce((a, b) => a < b ? a : b) - 2)
        .floorToDouble();
    final maxY   = (ys.reduce((a, b) => a > b ? a : b) + 2)
        .ceilToDouble();
    final current = ys.last;
    final targetW = double.tryParse(
        _profile?['target_weight']?.toString() ?? '0') ??
        0;
    final diff  = current - targetW;
    final trend = ys.length >= 2 ? ys.last - ys[ys.length - 2] : 0.0;

    final interval = (logs.length / 5).ceilToDouble().clamp(1.0, 10.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _chartCard(
            title: 'Évolution du poids (30 derniers jours)',
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.shade100,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      interval: 2,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textGray,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: interval,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= logs.length) {
                          return const SizedBox();
                        }
                        final raw = (logs[idx]['logged_at']
                                ?? logs[idx]['created_at'])
                            ?.toString() ??
                            '';
                        final parts = raw.split('T')[0].split('-');
                        if (parts.length < 3) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${parts[2]}/${parts[1]}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.textGray,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor:
                        Colors.blueAccent.withOpacity(0.85),
                    getTooltipItems: (touched) => touched
                        .map((s) => LineTooltipItem(
                              '${s.y.toStringAsFixed(1)} kg',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: Colors.blue,
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  label: 'Poids actuel',
                  value: '${current.toStringAsFixed(1)} kg',
                  color: Colors.blue,
                  icon: Icons.monitor_weight_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  label: 'Poids cible',
                  value: targetW > 0
                      ? '${targetW.toStringAsFixed(1)} kg'
                      : '--',
                  color: AppTheme.primary,
                  icon: Icons.flag_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  label: 'Différence',
                  value: targetW > 0
                      ? '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg'
                      : '--',
                  color: diff > 0 ? Colors.orange : Colors.green,
                  icon: diff > 0
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  label: 'Tendance',
                  value: trend == 0
                      ? 'Stable'
                      : '${trend > 0 ? '↑' : '↓'} ${trend.abs().toStringAsFixed(1)} kg',
                  color: trend > 0 ? Colors.red : Colors.green,
                  icon: trend > 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                ),
              ),
            ],
          ),
          if (!widget.isDoctor) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openWeightPicker,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter pesée'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _openWeightPicker() {
    final ys = _weightLogs
        .map((e) =>
            double.tryParse(e['weight_kg']?.toString() ?? '0') ?? 0)
        .where((v) => v > 0);
    final initial = ys.isNotEmpty ? ys.last : 70.0;
    showRulerPicker(
      context: context,
      title: 'Ajouter une pesée',
      subtitle: 'Faites glisser pour ajuster votre poids',
      initialValue: initial,
      minValue: 30,
      maxValue: 200,
      step: 1,
      unit: 'kg',
      onDone: _addWeightLog,
    );
  }

  // ─── ONGLET SCORE ──────────────────────────────────────────────────

  Widget _buildScoreTab() {
    if (_scoreLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    final sorted = [..._scoreLogs]..sort((a, b) {
        final da = a['score_date']?.toString() ?? '';
        final db = b['score_date']?.toString() ?? '';
        return da.compareTo(db);
      });

    final last14 = sorted.length > 14
        ? sorted.sublist(sorted.length - 14)
        : sorted;

    if (last14.isEmpty) {
      return _emptyState(
        'Aucun score disponible',
        Icons.emoji_events_outlined,
      );
    }

    final last7 = sorted.length > 7
        ? sorted.sublist(sorted.length - 7)
        : sorted;
    final avg7 = last7.isEmpty
        ? 0.0
        : last7.fold<double>(
                0,
                (s, e) =>
                    s +
                    (double.tryParse(
                            e['total_score']?.toString() ?? '0') ??
                        0)) /
            last7.length;

    final barGroups = last14.asMap().entries.map((e) {
      final score = double.tryParse(
              e.value['total_score']?.toString() ?? '0') ??
          0;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: score,
            color: _scoreColor(score),
            width: 14,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Badge moyenne 7 jours
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _scoreColor(avg7).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _scoreColor(avg7).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics_outlined,
                    color: _scoreColor(avg7), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Moyenne 7 derniers jours',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGray,
                        ),
                      ),
                      Text(
                        '${avg7.toStringAsFixed(1)} / 100',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _scoreColor(avg7),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  avg7 >= 90
                      ? 'Excellent'
                      : avg7 >= 70
                          ? 'Bon'
                          : 'À améliorer',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _scoreColor(avg7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _chartCard(
            title: 'Scores des 14 derniers jours',
            child: BarChart(
              BarChartData(
                maxY: 100,
                minY: 0,
                barGroups: barGroups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.shade100,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 70,
                      color: Colors.orange.withOpacity(0.6),
                      strokeWidth: 1.5,
                      dashArray: [5, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        labelResolver: (_) => 'Min. 70',
                      ),
                    ),
                  ],
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 20,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textGray,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= last14.length) {
                          return const SizedBox();
                        }
                        final raw =
                            last14[idx]['score_date']?.toString() ??
                                '';
                        final parts =
                            raw.split('T')[0].split('-');
                        if (parts.length < 3) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${parts[2]}/${parts[1]}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.textGray,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.grey.shade800,
                    getTooltipItem: (_, __, rod, ___) =>
                        BarTooltipItem(
                      '${rod.toY.toInt()}/100',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── ONGLET HYDRATATION ────────────────────────────────────────────

  Widget _buildWaterTab() {
    if (_waterLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_waterLogs.isEmpty) {
      return _emptyState(
        'Aucune donnée d\'hydratation',
        Icons.water_drop_outlined,
      );
    }

    const target = 2500;

    final barGroups = _waterLogs.asMap().entries.map((e) {
      final ml    = (e.value['amount_ml'] as num?)?.toInt() ?? 0;
      final isOver = ml >= target;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: ml.toDouble(),
            color: isOver
                ? Colors.blue.shade700
                : Colors.blue.shade400,
            width: 22,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    final total = _waterLogs.fold<int>(
      0, (s, e) => s + ((e['amount_ml'] as num?)?.toInt() ?? 0));
    final avg   = _waterLogs.isEmpty ? 0 : total ~/ _waterLogs.length;
    final maxYRaw = _waterLogs
        .map((e) => (e['amount_ml'] as num?)?.toDouble() ?? 0)
        .fold<double>(target.toDouble(), (a, b) => a > b ? a : b);
    final maxY  = (maxYRaw + 400).ceilToDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard(
                  label: 'Total semaine',
                  value: '${(total / 1000).toStringAsFixed(1)} L',
                  color: Colors.blue,
                  icon: Icons.water_drop_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  label: 'Moyenne / jour',
                  value: '$avg ml',
                  color: avg >= target
                      ? Colors.blue.shade700
                      : Colors.blue.shade400,
                  icon: Icons.show_chart,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _chartCard(
            title: 'Hydratation — 7 derniers jours',
            subtitle: Row(
              children: [
                Container(width: 10, height: 10,
                    color: Colors.blue.shade400),
                const SizedBox(width: 4),
                const Text('< 2500 ml',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textGray,
                    )),
                const SizedBox(width: 10),
                Container(width: 10, height: 10,
                    color: Colors.blue.shade700),
                const SizedBox(width: 4),
                const Text('≥ 2500 ml',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textGray,
                    )),
              ],
            ),
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                barGroups: barGroups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 500,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.shade100,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: target.toDouble(),
                      color: Colors.blue.withOpacity(0.5),
                      strokeWidth: 1.5,
                      dashArray: [5, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        labelResolver: (_) => '2500 ml',
                      ),
                    ),
                  ],
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: 500,
                      getTitlesWidget: (v, _) => Text(
                        v >= 1000
                            ? '${(v / 1000).toStringAsFixed(1)}L'
                            : '${v.toInt()}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.textGray,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= _waterLogs.length) {
                          return const SizedBox();
                        }
                        final date =
                            _waterLogs[idx]['date'] as String? ?? '';
                        final parts = date.split('-');
                        if (parts.length < 3) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${parts[2]}/${parts[1]}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.textGray,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.blueGrey.shade800,
                    getTooltipItem: (_, __, rod, ___) =>
                        BarTooltipItem(
                      '${rod.toY.toInt()} ml',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── WIDGETS COMMUNS ───────────────────────────────────────────────

  Widget _chartCard({
    required String title,
    required Widget child,
    Widget? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            subtitle,
          ],
          const SizedBox(height: 20),
          SizedBox(height: 220, child: child),
        ],
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGray,
                    )),
                Text(value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(
    String msg,
    IconData icon, {
    bool showAddButton = false,
    VoidCallback? onAdd,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: AppTheme.textGray),
          const SizedBox(height: 12),
          Text(msg,
              style: const TextStyle(
                color: AppTheme.textGray,
                fontSize: 14,
              )),
          if (showAddButton && onAdd != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter pesée'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
