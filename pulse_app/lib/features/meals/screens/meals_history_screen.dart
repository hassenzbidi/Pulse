import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import 'food_search_screen.dart';
import 'scanner_screen.dart';
import 'photo_analysis_screen.dart';

class MealsHistoryScreen extends StatefulWidget {
  final String userId;
  const MealsHistoryScreen({super.key, required this.userId});

  @override
  State<MealsHistoryScreen> createState() =>
      _MealsHistoryScreenState();
}

class _MealsHistoryScreenState
    extends State<MealsHistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  List     _meals        = [];
  bool     _isLoading    = true;
  // Cache : clé date → repas existent (pour le point vert)
  final Map<String, bool> _hasCache = {};

  // Définitions des 4 types de repas
  List<Map<String, dynamic>> get _mealDefs => [
    {
      'type':  'breakfast',
      'label': 'Petit-déjeuner',
      'icon':  Icons.wb_sunny_outlined,
      'color': Colors.orange,
    },
    {
      'type':  'lunch',
      'label': 'Déjeuner',
      'icon':  Icons.lunch_dining_outlined,
      'color': Colors.green,
    },
    {
      'type':  'dinner',
      'label': 'Dîner',
      'icon':  Icons.dinner_dining_outlined,
      'color': Colors.indigo,
    },
    {
      'type':  'snack',
      'label': 'Snacks',
      'icon':  Icons.apple_outlined,
      'color': Colors.red,
    },
  ];

  static const _dayAbbr = [
    'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim',
  ];
  static const _monthAbbr = [
    'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
    'juil', 'août', 'sep', 'oct', 'nov', 'déc',
  ];

  @override
  void initState() {
    super.initState();
    _loadMeals();
    _preloadWeekDots();
  }

  String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

  bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isToday => _isSameDay(_selectedDate, DateTime.now());

  double get _totalCalories => _meals.fold(0.0, (s, m) =>
    s + (double.tryParse(m['total_cal']?.toString() ?? '0') ?? 0));

  // Charge les repas pour la date sélectionnée
  Future<void> _loadMeals() async {
    setState(() { _isLoading = true; });
    try {
      final res = await ApiClient.dio.get(
        '/meals/bydate/${widget.userId}',
        queryParameters: {'date': _dateKey(_selectedDate)},
      );
      final meals = res.data['meals'] as List? ?? [];
      if (mounted) {
        setState(() {
          _meals    = meals;
          _isLoading = false;
          _hasCache[_dateKey(_selectedDate)] = meals.isNotEmpty;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // Précharge les 7 jours pour afficher les points verts
  Future<void> _preloadWeekDots() async {
    final today  = DateTime.now();
    final temp   = <String, bool>{};
    final futures = <Future<void>>[];

    for (var i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: 6 - i));
      final key  = _dateKey(date);
      futures.add(
        ApiClient.dio.get(
          '/meals/bydate/${widget.userId}',
          queryParameters: {'date': key},
        ).then((res) {
          final meals = res.data['meals'] as List? ?? [];
          temp[key] = meals.isNotEmpty;
        }).catchError((_) {
          temp[key] = false;
        }),
      );
    }
    await Future.wait(futures);
    if (mounted) setState(() { _hasCache.addAll(temp); });
  }

  void _selectDate(DateTime date) {
    if (_isSameDay(date, _selectedDate)) return;
    setState(() { _selectedDate = date; });
    _loadMeals();
  }

  // Ouvre le sélecteur de type de repas puis le menu d'ajout
  void _showMealTypePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ajouter à quel repas ?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              )),
            const SizedBox(height: 12),
            ..._mealDefs.map((mt) {
              final color = mt['color'] as Color;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(mt['icon'] as IconData,
                    color: color, size: 20),
                ),
                title: Text(mt['label'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDark,
                  )),
                onTap: () {
                  Navigator.pop(context);
                  _showAddMealMenu(
                    context, mt['type'] as String);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddMealMenu(BuildContext ctx, String mealType) {
    final labels = {
      'breakfast': 'Petit-déjeuner',
      'lunch':     'Déjeuner',
      'dinner':    'Dîner',
      'snack':     'Snack',
    };
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajouter à — ${labels[mealType] ?? mealType}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              )),
            const SizedBox(height: 20),
            _menuOption(
              icon: Icons.search,
              color: AppTheme.primary,
              label: 'Rechercher un aliment',
              subtitle: 'Base tunisienne + mondiale',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => FoodSearchScreen(
                    userId:   widget.userId,
                    mealType: mealType,
                  ),
                )).then((_) => _loadMeals());
              },
            ),
            const SizedBox(height: 10),
            _menuOption(
              icon: Icons.qr_code_scanner,
              color: Colors.blue,
              label: 'Scanner le code barre',
              subtitle: 'Open Food Facts',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => ScannerScreen(
                    userId: widget.userId),
                )).then((_) => _loadMeals());
              },
            ),
            const SizedBox(height: 10),
            _menuOption(
              icon: Icons.camera_alt_outlined,
              color: Colors.purple,
              label: 'Analyser une photo',
              subtitle: 'Gemini Vision IA',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => PhotoAnalysisScreen(
                    userId: widget.userId),
                )).then((_) => _loadMeals());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _menuOption({
    required IconData  icon,
    required Color     color,
    required String    label,
    required String    subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:  color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: color,
                    )),
                  Text(subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textGray,
                    )),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
              color: color.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dateLabel = _isToday
        ? 'Aujourd\'hui'
        : '${_selectedDate.day} '
          '${_monthAbbr[_selectedDate.month - 1]}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(dateLabel),
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showMealTypePicker,
            tooltip: 'Ajouter un repas',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCalendar(),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator(
                  color: AppTheme.primary))
              : _buildMealsList(),
          ),
        ],
      ),
    );
  }

  // Calendrier horizontal 7 jours
  Widget _buildCalendar() {
    final today = DateTime.now();
    return Container(
      color: AppTheme.white,
      height: 86,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
        itemCount: 7,
        itemBuilder: (_, i) {
          final date       = today.subtract(Duration(days: 6 - i));
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday    = _isSameDay(date, today);
          final hasMeals   = _hasCache[_dateKey(date)] ?? false;
          final dayAbbr    = _dayAbbr[date.weekday - 1];

          return GestureDetector(
            onTap: () => _selectDate(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: isToday && !isSelected
                    ? Border.all(
                        color: AppTheme.primary, width: 1.5)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayAbbr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white70
                          : AppTheme.textGray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasMeals
                          ? (isSelected
                              ? Colors.white
                              : Colors.green)
                          : Colors.transparent,
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

  // Liste des repas du jour
  Widget _buildMealsList() {
    if (_meals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant_outlined,
                size: 48, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            const Text('Aucun repas ce jour',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              )),
            const SizedBox(height: 8),
            const Text('Appuyez sur + pour ajouter un repas',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textGray,
              )),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Total calories du jour
        _buildTotalCaloriesCard(),
        const SizedBox(height: 16),

        // Repas groupés par type
        ..._mealDefs.map((mt) {
          final typeMeals = _meals
            .where((m) => m['meal_type'] == mt['type'])
            .toList();
          if (typeMeals.isEmpty) return const SizedBox.shrink();
          return _buildMealTypeSection(mt, typeMeals);
        }),
      ],
    );
  }

  // Carte total calories
  Widget _buildTotalCaloriesCard() {
    final total = _totalCalories;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department,
            color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total du jour',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  )),
                Text(
                  '${total.toInt()} kcal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  )),
              ],
            ),
          ),
          Text(
            '${_meals.length} repas',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            )),
        ],
      ),
    );
  }

  // Section d'un type de repas
  Widget _buildMealTypeSection(
      Map<String, dynamic> mt, List meals) {
    final color = mt['color'] as Color;
    final icon  = mt['icon'] as IconData;
    final label = mt['label'] as String;

    final sectionCal = meals.fold<double>(0, (s, m) =>
      s + (double.tryParse(
        m['total_cal']?.toString() ?? '0') ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // En-tête du type
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    )),
                ),
                Text('${sectionCal.toInt()} kcal',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  )),
              ],
            ),
          ),
          const Divider(height: 1, indent: 14, endIndent: 14),
          // Liste des repas de ce type
          ...meals.asMap().entries.map((e) {
            final isLast = e.key == meals.length - 1;
            return _buildMealItem(e.value, isLast: isLast);
          }),
        ],
      ),
    );
  }

  // Item d'un repas individuel
  Widget _buildMealItem(Map meal, {bool isLast = false}) {
    final cal    = double.tryParse(
        meal['total_cal']?.toString() ?? '0') ?? 0;
    final time   = _formatTime(
        meal['eaten_at']?.toString() ?? '');
    final items  = meal['items'] as List? ?? [];
    final prot   = double.tryParse(
        meal['total_prot']?.toString() ?? '0') ?? 0;
    final carbs  = double.tryParse(
        meal['total_carbs']?.toString() ?? '0') ?? 0;
    final fat    = double.tryParse(
        meal['total_fat']?.toString() ?? '0') ?? 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: items.isNotEmpty
                      ? Wrap(
                          spacing: 4,
                          children: items.take(3).map((it) =>
                            Text(
                              it['food_name'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ).toList(),
                        )
                      : const Text('Repas enregistré',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textDark,
                          )),
                  ),
                  const SizedBox(width: 8),
                  Text('${cal.toInt()} kcal',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    )),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  if (time.isNotEmpty) ...[
                    const Icon(Icons.access_time,
                      size: 12, color: AppTheme.textGray),
                    const SizedBox(width: 3),
                    Text(time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textGray,
                      )),
                    const SizedBox(width: 12),
                  ],
                  _macroChip(
                    '${prot.toInt()}g P', Colors.blue),
                  const SizedBox(width: 6),
                  _macroChip(
                    '${carbs.toInt()}g G', Colors.orange),
                  const SizedBox(width: 6),
                  _macroChip(
                    '${fat.toInt()}g L', Colors.red),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 14, endIndent: 14),
      ],
    );
  }

  Widget _macroChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        )),
    );
  }

  String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:'
             '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
