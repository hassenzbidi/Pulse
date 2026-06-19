import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import 'add_specialist_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() =>
    _AdminDashboardScreenState();
}

class _AdminDashboardScreenState
    extends State<AdminDashboardScreen> {
  int  _currentTab    = 0;
  Map? _stats;
  List _patients      = [];
  List _doctors       = [];
  List _pendingDoctors = [];
  bool _isLoading     = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    try {
      final results = await Future.wait([
        ApiClient.dio.get('/admin/stats',
          options: Options(headers: ApiClient.adminHeaders)),
        ApiClient.dio.get('/admin/patients',
          options: Options(headers: ApiClient.adminHeaders)),
        ApiClient.dio.get('/admin/doctors',
          options: Options(headers: ApiClient.adminHeaders)),
        ApiClient.dio.get('/admin/pending-doctors',
          options: Options(headers: ApiClient.adminHeaders)),
      ]);
      setState(() {
        _stats          = results[0].data;
        _patients       = results[1].data['patients']       ?? [];
        _doctors        = results[2].data['doctors']        ?? [];
        _pendingDoctors = results[3].data['doctors']        ?? [];
        _isLoading      = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _toggleVerify(
      String doctorId, bool current) async {
    try {
      await ApiClient.dio.patch(
        '/admin/doctor/$doctorId/verify',
        data: { 'is_verified': !current },
        options: Options(headers: ApiClient.adminHeaders),
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!current
              ? 'Médecin vérifié ✅'
              : 'Vérification retirée'),
            backgroundColor: !current
              ? AppTheme.primary : Colors.orange,
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

  Future<void> _verifyDoctor(
      String doctorId, bool approve) async {
    try {
      await ApiClient.dio.patch(
        '/admin/doctor/$doctorId/verify',
        data: { 'is_verified': approve },
        options: Options(headers: ApiClient.adminHeaders),
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve
              ? 'Médecin approuvé ✅'
              : 'Médecin rejeté'),
            backgroundColor: approve
              ? Colors.green : Colors.red,
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

  void _showPdfDialog(
      BuildContext context, String title, String? base64Data) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf,
                    color: Colors.red, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textDark,
                        )),
                      Text('Document PDF',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGray,
                        )),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              if (base64Data != null && base64Data.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle,
                        color: Colors.green, size: 40),
                      const SizedBox(height: 8),
                      const Text('Document reçu',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textDark,
                        )),
                      const SizedBox(height: 4),
                      Text(
                        '${(base64Data.length * 0.75 / 1024).toStringAsFixed(1)} KB',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGray,
                        )),
                    ],
                  ),
                ),
              ] else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.warning_amber,
                        color: Colors.orange, size: 32),
                      SizedBox(height: 8),
                      Text('Aucun document fourni',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange,
                        )),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (!_isLoading) _buildStats(),
            _buildTabs(),
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator(
                    color: AppTheme.primary))
                : _currentTab == 0
                  ? _buildPatientsList()
                  : _currentTab == 1
                    ? _buildDoctorsList()
                    : _buildPendingList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2E2A),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Espace Admin',
                style: TextStyle(
                  color: Colors.white70, fontSize: 13)),
              Text('Pulse Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                )),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh,
                  color: Colors.white),
                onPressed: _loadData,
              ),
              IconButton(
                icon: const Icon(Icons.person_add,
                  color: Colors.white),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddSpecialistScreen()),
                ),
                tooltip: 'Ajouter un spécialiste',
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout,
                    color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    if (_stats == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1A2E2A),
      child: Row(
        children: [
          _statCard('Patients',
            '${_stats!['total_patients'] ?? 0}',
            Icons.people_outlined, Colors.blue),
          const SizedBox(width: 8),
          _statCard('Médecins',
            '${_stats!['total_doctors'] ?? 0}',
            Icons.medical_services_outlined,
            Colors.green),
          const SizedBox(width: 8),
          _statCard('Suivis actifs',
            '${_stats!['total_access'] ?? 0}',
            Icons.favorite_outlined, AppTheme.primary),
          const SizedBox(width: 8),
          _statCard('Score moy.',
            '${_stats!['avg_score'] ?? 0}',
            Icons.star_outlined, Colors.orange),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value,
      IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              )),
            Text(label,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white54,
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _tabBtn('Patients', 0,
            Icons.people_outlined),
          _tabBtn('Médecins', 1,
            Icons.medical_services_outlined),
          _tabBtn('En attente', 2,
            Icons.hourglass_top_outlined,
            badge: _pendingDoctors.length),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int index, IconData icon,
      {int badge = 0}) {
    final isActive = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive
                  ? AppTheme.primary
                  : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                    size: 15,
                    color: isActive
                      ? AppTheme.primary
                      : AppTheme.textGray),
                  const SizedBox(width: 5),
                  Text(label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive
                        ? FontWeight.w600
                        : FontWeight.normal,
                      color: isActive
                        ? AppTheme.primary
                        : AppTheme.textGray,
                    )),
                ],
              ),
              if (badge > 0)
                Positioned(
                  right: 4, top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text('$badge',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      )),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientsList() {
    if (_patients.isEmpty) {
      return const Center(
        child: Text('Aucun patient',
          style: TextStyle(color: AppTheme.textGray)));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _patients.length,
        itemBuilder: (_, i) =>
          _buildPatientCard(_patients[i]),
      ),
    );
  }

  Widget _buildPatientCard(Map p) {
    final score = double.tryParse(
      p['last_score']?.toString() ?? '0') ?? 0;
    final weight = double.tryParse(
      p['last_weight']?.toString() ?? '0') ?? 0;
    final meals  = int.tryParse(
      p['total_meals']?.toString() ?? '0') ?? 0;
    final date   = p['created_at']
      ?.toString().split('T')[0] ?? '';

    Color scoreColor = score >= 90
      ? Colors.green
      : score >= 70 ? Colors.orange : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
              AppTheme.primary.withOpacity(0.1),
            child: Text(
              (p['full_name'] ?? 'P')[0].toUpperCase(),
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
                Text(p['full_name'] ?? 'Patient',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textDark,
                  )),
                Text(p['email'] ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textGray,
                  )),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    if (weight > 0)
                      _miniChip(
                        '${weight.toInt()} kg',
                        Colors.blue),
                    _miniChip('$meals repas',
                      Colors.purple),
                    _miniChip('Inscrit $date',
                      Colors.grey),
                  ],
                ),
              ],
            ),
          ),
          if (score > 0)
            Column(
              children: [
                Text('${score.toInt()}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  )),
                Text('/100',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textGray,
                  )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDoctorsList() {
    if (_doctors.isEmpty) {
      return const Center(
        child: Text('Aucun médecin',
          style: TextStyle(color: AppTheme.textGray)));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _doctors.length,
        itemBuilder: (_, i) =>
          _buildDoctorCard(_doctors[i]),
      ),
    );
  }

  Widget _buildDoctorCard(Map d) {
    final isVerified = d['is_verified'] == true;
    final patients   = int.tryParse(
      d['patient_count']?.toString() ?? '0') ?? 0;
    final date       = d['created_at']
      ?.toString().split('T')[0] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isVerified
          ? Border.all(
              color: AppTheme.primary.withOpacity(0.3))
          : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isVerified
              ? AppTheme.primary.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
            child: Text(
              (d['full_name'] ?? 'D')[0].toUpperCase(),
              style: TextStyle(
                color: isVerified
                  ? AppTheme.primary
                  : Colors.grey,
                fontWeight: FontWeight.bold,
              )),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Dr. ${d['full_name'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textDark,
                      )),
                    const SizedBox(width: 6),
                    if (isVerified)
                      const Icon(Icons.verified,
                        color: AppTheme.primary,
                        size: 16),
                  ],
                ),
                if (d['speciality'] != null)
                  Text(d['speciality'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                    )),
                if (d['hospital'] != null)
                  Text(d['hospital'],
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGray,
                    )),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    _miniChip(
                      '$patients patient(s)',
                      Colors.blue),
                    _miniChip('Inscrit $date',
                      Colors.grey),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggleVerify(
              d['id'], isVerified),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isVerified
                  ? Colors.red.withOpacity(0.1)
                  : AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isVerified ? 'Retirer' : 'Vérifier',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isVerified
                    ? Colors.red
                    : AppTheme.primary,
                )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingList() {
    if (_pendingDoctors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
              size: 64, color: Colors.green[300]),
            const SizedBox(height: 16),
            const Text('Aucune demande en attente',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              )),
            const SizedBox(height: 8),
            const Text('Toutes les demandes ont été traitées',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textGray,
              )),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pendingDoctors.length,
        itemBuilder: (_, i) =>
          _buildPendingCard(_pendingDoctors[i]),
      ),
    );
  }

  Widget _buildPendingCard(Map d) {
    final date = d['created_at']
      ?.toString().split('T')[0] ?? '';
    final hasCv      = d['cv_pdf'] != null &&
                       (d['cv_pdf'] as String).isNotEmpty;
    final hasDiploma = d['diploma_pdf'] != null &&
                       (d['diploma_pdf'] as String).isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                  Colors.orange.withOpacity(0.1),
                child: Text(
                  (d['full_name'] ?? 'D')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['full_name'] ?? 'Spécialiste',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textDark,
                      )),
                    Text(d['email'] ?? '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textGray,
                      )),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('En attente',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  )),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Infos
          Wrap(
            spacing: 8, runSpacing: 6,
            children: [
              if (d['speciality'] != null)
                _miniChip(d['speciality'], AppTheme.primary),
              if (d['hospital'] != null)
                _miniChip(d['hospital'], Colors.blue),
              _miniChip('Inscrit $date', Colors.grey),
            ],
          ),

          if (d['bio'] != null &&
              (d['bio'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(d['bio'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textGray,
              )),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Boutons documents
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showPdfDialog(
                    context,
                    'CV de ${d['full_name'] ?? ''}',
                    d['cv_pdf'] as String?,
                  ),
                  icon: Icon(
                    Icons.picture_as_pdf,
                    size: 16,
                    color: hasCv ? Colors.red : Colors.grey,
                  ),
                  label: Text('Voir CV',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasCv ? Colors.red : Colors.grey,
                    )),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: hasCv
                        ? Colors.red.withOpacity(0.4)
                        : Colors.grey.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showPdfDialog(
                    context,
                    'Diplôme de ${d['full_name'] ?? ''}',
                    d['diploma_pdf'] as String?,
                  ),
                  icon: Icon(
                    Icons.school,
                    size: 16,
                    color: hasDiploma
                      ? Colors.indigo : Colors.grey,
                  ),
                  label: Text('Voir Diplôme',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasDiploma
                        ? Colors.indigo : Colors.grey,
                    )),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: hasDiploma
                        ? Colors.indigo.withOpacity(0.4)
                        : Colors.grey.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Boutons approbation
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                    _verifyDoctor(d['id'], true),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approuver',
                    style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                    _verifyDoctor(d['id'], false),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Rejeter',
                    style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String label, Color color) {
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
}
