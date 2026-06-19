import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../main.dart';
import '../../meals/screens/scanner_screen.dart';
import '../../meals/screens/meals_history_screen.dart';
import '../../meals/screens/photo_analysis_screen.dart';
import '../../meals/screens/food_search_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/screens/discussion_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../scores/screens/score_screen.dart';
import '../../stats/screens/stats_screen.dart';
import '../../../core/widgets/notification_badge.dart';

class DashboardScreen extends StatefulWidget {
  final String userId;
  const DashboardScreen({super.key, required this.userId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with RouteAware {

  int      _currentIndex = 0;
  Map?     _profile;
  List     _meals        = [];
  List     _myDoctors    = [];
  int      _chatUnread   = 0;
  bool     _isLoading    = true;
  int      _waterMl      = 0;
  int      _waterTarget  = 2500;
  final int _waterStep   = 250;
  DateTime _selectedDate = DateTime.now();
  Map?     _dayScore;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadChatUnread();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadData();
    _loadChatUnread();
  }

  String _formatDateForApi(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2,'0')}-'
    '${date.day.toString().padLeft(2,'0')}';

  Future<void> _loadData() async {
    try {
      final userRes = await ApiClient.dio.get(
        '/auth/user/${widget.userId}',
      );
      final profileRes = await ApiClient.dio.get(
        '/profile/${widget.userId}',
      );
      final mealsRes = await ApiClient.dio.get(
        '/meals/bydate/${widget.userId}',
        queryParameters: {
          'date': _formatDateForApi(_selectedDate),
        },
      );
      final waterRes = await ApiClient.dio.get(
        '/weight/water/${widget.userId}',
        queryParameters: {
          'date': _formatDateForApi(_selectedDate),
        },
      );
      final scoresRes = await ApiClient.dio.get(
        '/scores/history/${widget.userId}',
      );
      final doctorsRes = await ApiClient.dio.get(
        '/doctor/my-doctors/${widget.userId}',
      );
      final scores  = scoresRes.data['scores'] as List;
      final dateStr = _formatDateForApi(_selectedDate);
      Map? selectedScore;
      for (final s in scores) {
        final d = s['score_date']?.toString().split('T')[0];
        if (d == dateStr) { selectedScore = s; break; }
      }
      setState(() {
        _profile = {
          ...?profileRes.data['profile'],
          'full_name': userRes.data['user']['full_name']
              ?? 'Utilisateur',
        };
        _meals      = mealsRes.data['meals'] ?? [];
        _waterMl    = waterRes.data['amount_ml'] ?? 0;
        _dayScore   = selectedScore;
        _myDoctors  = doctorsRes.data['doctors'] as List? ?? [];
        _isLoading  = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _saveWater() async {
    try {
      await ApiClient.dio.post('/weight/water', data: {
        'user_id':   widget.userId,
        'amount_ml': _waterMl,
        'date':      _formatDateForApi(_selectedDate),
      });
    } catch (e) {}
  }

  Future<void> _showCalendar() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _isLoading    = true;
        _meals        = [];
        _waterMl      = 0;
        _dayScore     = null;
      });
      _loadData();
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year  == now.year  &&
           _selectedDate.month == now.month &&
           _selectedDate.day   == now.day;
  }

  double get _totalCalories => _meals.fold(0.0, (s, m) =>
    s + (double.tryParse(m['total_cal']?.toString() ?? '0') ?? 0));

  double get _targetCalories => double.tryParse(
    _profile?['daily_calories']?.toString() ?? '0') ?? 0;

  double get _totalProt => _meals.fold(0.0, (s, m) =>
    s + (double.tryParse(m['total_prot']?.toString() ?? '0') ?? 0));

  double get _totalCarbs => _meals.fold(0.0, (s, m) =>
    s + (double.tryParse(m['total_carbs']?.toString() ?? '0') ?? 0));

  double get _totalFat => _meals.fold(0.0, (s, m) =>
    s + (double.tryParse(m['total_fat']?.toString() ?? '0') ?? 0));

  double get _targetProt => double.tryParse(
    _profile?['protein_g']?.toString() ?? '0') ?? 0;

  double get _targetCarbs => double.tryParse(
    _profile?['carbs_g']?.toString() ?? '0') ?? 0;

  double get _targetFat => double.tryParse(
    _profile?['fat_g']?.toString() ?? '0') ?? 0;

  String get _dateLabel {
    if (_isToday) return 'Aujourd\'hui';
    final diff = DateTime.now().difference(_selectedDate).inDays;
    if (diff == 1) return 'Hier';
    const months = [
      'jan','fév','mar','avr','mai','juin',
      'juil','août','sep','oct','nov','déc'
    ];
    return '${_selectedDate.day} '
           '${months[_selectedDate.month - 1]} '
           '${_selectedDate.year}';
  }

  String get _weekday {
    const days = [
      'Lundi','Mardi','Mercredi','Jeudi',
      'Vendredi','Samedi','Dimanche'
    ];
    return days[_selectedDate.weekday - 1];
  }

  Color _scoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  void _showAddMealMenu(BuildContext context, [String? mealType]) {
    const labels = {
      'breakfast': 'Petit-déjeuner',
      'lunch':     'Déjeuner',
      'dinner':    'Dîner',
      'snack':     'Snack',
    };
    final mealDefs = [
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
        'label': 'Snack',
        'icon':  Icons.apple_outlined,
        'color': Colors.red,
      },
    ];

    String? selectedType = mealType;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          // ── Phase 2 : options d'ajout ─────────────────────
          if (selectedType != null) {
            final type = selectedType!;
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (mealType == null)
                        GestureDetector(
                          onTap: () =>
                            setSheetState(() => selectedType = null),
                          child: const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Icon(Icons.arrow_back_ios,
                              size: 18,
                              color: AppTheme.textGray),
                          ),
                        ),
                      Text(
                        'Ajouter à — ${labels[type] ?? type}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        )),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _menuOption(
                    icon: Icons.search,
                    color: AppTheme.primary,
                    label: 'Rechercher un aliment',
                    subtitle: 'Base tunisienne + mondiale',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => FoodSearchScreen(
                          userId:   widget.userId,
                          mealType: type,
                        ),
                      ));
                    },
                  ),
                  const SizedBox(height: 10),
                  _menuOption(
                    icon: Icons.qr_code_scanner,
                    color: Colors.blue,
                    label: 'Scanner le code barre',
                    subtitle: 'Open Food Facts',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ScannerScreen(
                          userId: widget.userId),
                      ));
                    },
                  ),
                  const SizedBox(height: 10),
                  _menuOption(
                    icon: Icons.camera_alt_outlined,
                    color: Colors.purple,
                    label: 'Analyser une photo',
                    subtitle: 'Gemini Vision IA',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PhotoAnalysisScreen(
                          userId: widget.userId),
                      ));
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          }

          // ── Phase 1 : sélection du type de repas ─────────
          return Container(
            padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 16),
                ...mealDefs.map((mt) {
                  final color = mt['color'] as Color;
                  return GestureDetector(
                    onTap: () => setSheetState(
                      () => selectedType = mt['type'] as String),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius:
                                BorderRadius.circular(8),
                            ),
                            child: Icon(mt['icon'] as IconData,
                              color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(mt['label'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                                color: AppTheme.textDark,
                              )),
                          ),
                          Icon(Icons.chevron_right,
                            color: color.withOpacity(0.5),
                            size: 20),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _menuOption({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1 — Contenu principal (derrière tout)
          Positioned.fill(
            child: _currentIndex == 2
                ? ChatScreen(userId: widget.userId)
                : _buildHome(),
          ),

          // 2 — Barre flottante
          Positioned(
            bottom: 16,
            left: 20,
            right: 20,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    onPressed: () => setState(() => _currentIndex = 0),
                    icon: Icon(
                      _currentIndex == 0
                          ? Icons.home
                          : Icons.home_outlined,
                      color: _currentIndex == 0
                          ? AppTheme.primary
                          : Colors.grey,
                    ),
                    tooltip: 'Accueil',
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MealsHistoryScreen(
                          userId: widget.userId),
                      ),
                    ),
                    icon: const Icon(
                      Icons.restaurant_outlined,
                      color: Colors.grey,
                    ),
                    tooltip: 'Repas',
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            StatsScreen(userId: widget.userId),
                      ),
                    ),
                    icon: const Icon(
                      Icons.bar_chart_outlined,
                      color: Colors.grey,
                    ),
                    tooltip: 'Graphiques',
                  ),
                  IconButton(
                    onPressed: () => setState(() => _currentIndex = 2),
                    icon: Icon(
                      _currentIndex == 2
                          ? Icons.chat
                          : Icons.chat_outlined,
                      color: _currentIndex == 2
                          ? AppTheme.primary
                          : Colors.grey,
                    ),
                    tooltip: 'NutriBot',
                  ),
                ],
              ),
            ),
          ),

          // 3 — Bouton + centré au-dessus de la barre
          Positioned(
            bottom: 44,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _showAddMealMenu(context, null),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),

          // 4 — Bulle spécialiste (au-dessus de tout)
          if (!_isLoading && _myDoctors.isNotEmpty)
            Positioned(
              bottom: 90,
              left: 16,
              width: 52,
              height: 52,
              child: _buildChatFab(),
            ),
        ],
      ),
    );
  }

  Future<void> _loadChatUnread() async {
    try {
      final res = await ApiClient.dio.get(
        '/chat/unread/${widget.userId}');
      if (mounted) {
        setState(() {
          _chatUnread =
            res.data['unread_count'] as int? ?? 0;
        });
      }
    } catch (_) {}
  }

  void _onChatFabTap() {
    if (_myDoctors.isEmpty) return;
    if (_myDoctors.length == 1) {
      final doc = _myDoctors[0];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DiscussionScreen(
            currentUserId: widget.userId,
            otherUserId:
              doc['doctor_id']?.toString() ?? '',
            otherName:
              doc['full_name'] ?? 'Médecin',
            otherRole: 'doctor',
          ),
        ),
      ).then((_) => _loadChatUnread());
    } else {
      _showDoctorPicker();
    }
  }

  void _showDoctorPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Discuter avec…',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              )),
            const SizedBox(height: 12),
            ..._myDoctors.map((doc) {
              final did  = doc['doctor_id']?.toString() ?? '';
              final name = doc['full_name'] ?? 'Médecin';
              final spec = doc['speciality'] ?? '';
              final init = name.isNotEmpty
                  ? name[0].toUpperCase() : 'M';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor:
                    AppTheme.primary.withOpacity(0.12),
                  child: Text(init,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    )),
                ),
                title: Text(name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  )),
                subtitle: spec.isNotEmpty
                  ? Text(spec,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                      ))
                  : null,
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppTheme.textGray,
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DiscussionScreen(
                        currentUserId: widget.userId,
                        otherUserId:   did,
                        otherName:     name,
                        otherRole:     'doctor',
                      ),
                    ),
                  ).then((_) => _loadChatUnread());
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildChatFab() {
    return GestureDetector(
      onTap: _onChatFabTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.chat,
              color: Colors.white,
              size: 26,
            ),
          ),
          if (_chatUnread > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _chatUnread > 9 ? '9+' : '$_chatUnread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_myDoctors.isNotEmpty) ...[
                  _buildDoctorsBanner(),
                  const SizedBox(height: 12),
                ],
                _buildCaloriesCard(),
                const SizedBox(height: 12),
                if (!_isToday) _buildHistorySummary(),
                if (!_isToday) const SizedBox(height: 12),
                if (_isToday) _buildWaterCard(),
                if (_isToday) const SizedBox(height: 16),
                _buildMealsSection(),
                const SizedBox(height: 140),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorsBanner() {
    final first     = _myDoctors[0];
    final name      = first['full_name']  ?? 'votre médecin';
    final specialty = first['speciality'] ?? first['specialty'] ?? '';
    final extra     = _myDoctors.length - 1;

    final label = StringBuffer('Votre profil est suivi par Dr. $name');
    if (specialty.isNotEmpty) label.write(' — $specialty');
    if (extra > 0) label.write(' et $extra autre${extra > 1 ? 's' : ''}');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medical_services,
              color: AppTheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label.toString(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    
    final score = _dayScore != null
      ? double.tryParse(
          _dayScore!['total_score']?.toString() ?? '0') ?? 0
      : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2E2A),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _showCalendar,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today,
                    color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_dateLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      )),
                    Text(_weekday,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      )),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge notifications
              SizedBox(
                width: 36,
                height: 36,
                child: NotificationBadge(userId: widget.userId),
              ),
              const SizedBox(width: 8),
              // Score compact
              GestureDetector(
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                    builder: (_) =>
                      ScoreScreen(userId: widget.userId),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    score != null
                      ? '${score.toInt()}/100'
                      : '--/100',
                    style: TextStyle(
                      color: score != null
                        ? _scoreColor(score)
                        : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Avatar profil
              GestureDetector(
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      userId:  widget.userId,
                      profile: _profile,
                    ),
                  ),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    (_profile?['full_name'] ?? 'U')[0]
                      .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySummary() {
    final score = _dayScore != null
      ? double.tryParse(
          _dayScore!['total_score']?.toString() ?? '0') ?? 0
      : null;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.water_drop_outlined,
                      color: Colors.blue.shade400, size: 18),
                    const SizedBox(width: 6),
                    const Text('Eau',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textDark,
                      )),
                  ],
                ),
                const SizedBox(height: 8),
                Text('$_waterMl ml',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _waterMl >= _waterTarget
                      ? Colors.blue.shade600
                      : AppTheme.textDark,
                  )),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_waterMl / _waterTarget)
                      .clamp(0.0, 1.0),
                    backgroundColor: Colors.blue.shade50,
                    valueColor: AlwaysStoppedAnimation(
                      Colors.blue.shade400),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text('/ $_waterTarget ml',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textGray,
                  )),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: score != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('🎯',
                          style: TextStyle(fontSize: 16)),
                        SizedBox(width: 6),
                        Text('Score',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textDark,
                          )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${score.toInt()}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _scoreColor(score),
                            ),
                          ),
                          const TextSpan(
                            text: '/100',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: score / 100,
                        backgroundColor: _scoreColor(score)
                          .withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(
                          _scoreColor(score)),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      score >= 90 ? 'Excellent'
                        : score >= 70 ? 'Bon'
                        : 'À améliorer',
                      style: TextStyle(
                        fontSize: 11,
                        color: _scoreColor(score),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('🎯',
                        style: TextStyle(fontSize: 16)),
                      SizedBox(width: 6),
                      Text('Score',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textDark,
                        )),
                    ]),
                    SizedBox(height: 8),
                    Text('Non calculé',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textGray,
                      )),
                  ],
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaloriesCard() {
    final pct = _targetCalories > 0
      ? (_totalCalories / _targetCalories).clamp(0.0, 1.0)
      : 0.0;
    final pctInt = (_targetCalories > 0
      ? (_totalCalories / _targetCalories) * 100
      : 0.0).toInt();
    final isOver = _totalCalories > _targetCalories
      && _targetCalories > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isToday ? 'Calories du jour'
                  : 'Calories — $_dateLabel',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                )),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOver
                    ? Colors.red.shade50
                    : AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_totalCalories.toInt()} / '
                  '${_targetCalories.toInt()} kcal',
                  style: TextStyle(
                    color: isOver
                      ? Colors.red.shade600
                      : AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 100, height: 100,
                child: Stack(
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 10,
                        backgroundColor: isOver
                          ? Colors.red.shade100
                          : Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation(
                          isOver ? Colors.red
                            : AppTheme.primary),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment:
                          MainAxisAlignment.center,
                        children: [
                          Text('$pctInt%',
                            style: TextStyle(
                              fontSize: isOver ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: isOver
                                ? Colors.red
                                : AppTheme.textDark,
                            )),
                          Text(
                            isOver ? 'dépassé !'
                              : 'de\nl\'objectif',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: isOver
                                ? Colors.red
                                : AppTheme.textGray,
                            )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildMacroRow('Protéines',
                      _totalProt, _targetProt, Colors.green),
                    const SizedBox(height: 12),
                    _buildMacroRow('Glucides',
                      _totalCarbs, _targetCarbs, Colors.orange),
                    const SizedBox(height: 12),
                    _buildMacroRow('Lipides',
                      _totalFat, _targetFat, Colors.red),
                  ],
                ),
              ),
            ],
          ),
          if (isOver) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                    color: Colors.red.shade400, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Objectif dépassé de '
                      '${(_totalCalories - _targetCalories)
                        .toInt()} kcal.',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacroRow(String label, double value,
      double target, Color color) {
    final pct = target > 0
      ? (value / target).clamp(0.0, 1.0)
      : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textGray,
              )),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${value.toInt()}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: '/${target.toInt()}g',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildWaterCard() {
    final pct = (_waterMl / _waterTarget).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.water_drop_outlined,
                      color: Colors.blue.shade400, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hydratation',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppTheme.textDark,
                        )),
                      Text('Objectif : $_waterTarget ml / jour',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textGray,
                        )),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _waterMl += _waterStep);
                  _saveWater();
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add,
                    color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$_waterMl ',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _waterMl >= _waterTarget
                      ? Colors.blue.shade400
                      : AppTheme.textDark,
                  ),
                ),
                TextSpan(
                  text: 'ml / $_waterTarget ml',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textGray,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.blue.shade50,
              valueColor: AlwaysStoppedAnimation(
                _waterMl >= _waterTarget
                  ? Colors.blue.shade600
                  : Colors.blue.shade400,
              ),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _waterMl >= _waterTarget
                  ? 'Objectif atteint !'
                  : '${(pct * 100).toInt()}% atteint',
                style: TextStyle(
                  color: _waterMl >= _waterTarget
                    ? Colors.blue.shade600
                    : AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                _waterMl >= _waterTarget
                  ? '+${_waterMl - _waterTarget} ml bonus'
                  : '${_waterTarget - _waterMl} ml restants',
                style: TextStyle(
                  color: _waterMl >= _waterTarget
                    ? Colors.blue.shade400
                    : AppTheme.textGray,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealsSection() {
    final totalTarget = _targetCalories > 0
      ? _targetCalories : 2000;
    final mealTypes = [
      {
        'type': 'breakfast',
        'label': 'Petit-déjeuner',
        'target': (totalTarget * 0.25).toInt(),
        'icon': Icons.wb_sunny_outlined,
        'color': Colors.orange,
      },
      {
        'type': 'lunch',
        'label': 'Déjeuner',
        'target': (totalTarget * 0.35).toInt(),
        'icon': Icons.lunch_dining_outlined,
        'color': Colors.green,
      },
      {
        'type': 'dinner',
        'label': 'Dîner',
        'target': (totalTarget * 0.30).toInt(),
        'icon': Icons.dinner_dining_outlined,
        'color': Colors.indigo,
      },
      {
        'type': 'snack',
        'label': 'Snacks',
        'target': (totalTarget * 0.10).toInt(),
        'icon': Icons.apple_outlined,
        'color': Colors.red,
      },
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isToday ? 'Repas du jour'
                : 'Repas — $_dateLabel',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              )),
            if (_isToday)
              GestureDetector(
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                    builder: (_) =>
                      ScoreScreen(userId: widget.userId),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Text('🎯',
                        style: TextStyle(fontSize: 14)),
                      SizedBox(width: 4),
                      Text('Score',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        )),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
          itemCount: mealTypes.length,
          itemBuilder: (_, i) {
            final mt     = mealTypes[i];
            final meal   = _meals.where(
              (m) => m['meal_type'] == mt['type']).toList();
            final cal    = meal.isEmpty ? 0.0
              : meal.fold<double>(0, (s, m) =>
                  s + (double.tryParse(
                    m['total_cal']?.toString() ?? '0') ?? 0));
            final target = mt['target'] as int;
            final pct    = (cal / target).clamp(0.0, 1.0);
            final color  = mt['color'] as Color;
            final over   = cal > target;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: over
                  ? Border.all(
                      color: Colors.red.shade200, width: 1.5)
                  : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(mt['icon'] as IconData,
                          color: color, size: 18),
                      ),
                      // Bouton + avec menu
                      GestureDetector(
                        onTap: () => _showAddMealMenu(
                          context, mt['type'] as String),
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: over
                                ? Colors.red
                                : AppTheme.primary,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            over
                              ? Icons.warning_amber
                              : Icons.add,
                            size: 16,
                            color: over
                              ? Colors.red
                              : AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(mt['label'] as String,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textDark,
                    )),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(
                        over ? Colors.red : color),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${cal.toInt()} / $target kcal',
                    style: TextStyle(
                      fontSize: 12,
                      color: over ? Colors.red : AppTheme.textGray,
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
    );
  }
}