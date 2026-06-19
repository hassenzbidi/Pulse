import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import 'patient_detail_screen.dart';
import 'pending_requests_screen.dart';
import '../../../core/widgets/notification_badge.dart';
import '../../auth/screens/login_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  const DoctorDashboardScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorDashboardScreen> createState() =>
    _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState
    extends State<DoctorDashboardScreen> {
  List  _patients  = [];
  List  _pending   = [];
  bool  _isLoading = true;

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
      final patientsRes = await ApiClient.dio.get(
        '/doctor/patients/${widget.doctorId}',
      );
      final pendingRes = await ApiClient.dio.get(
        '/doctor/pending/${widget.doctorId}',
      );
      setState(() {
        _patients  = patientsRes.data['patients'] ?? [];
        _pending   = pendingRes.data['requests']  ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _respondToRequest(
      String patientId, String status) async {
    try {
      await ApiClient.dio.patch(
        '/doctor/access/$patientId',
        data: {
          'doctor_id': widget.doctorId,
          'status':    status,
        },
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved'
              ? 'Patient accepté !'
              : 'Demande refusée'),
            backgroundColor: status == 'approved'
              ? AppTheme.primary
              : Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(
              color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppTheme.primary,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader()),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (_pending.isNotEmpty)
                          _buildPendingSection(),
                        if (_pending.isNotEmpty)
                          const SizedBox(height: 16),
                        _buildPatientsSection(),
                        const SizedBox(height: 24),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2E2A),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Espace médecin',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                )),
              const SizedBox(height: 2),
              Text(
                'Dr. ${widget.doctorName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_patients.length} patient(s)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (_pending.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_pending.length} en attente',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          NotificationBadge(userId: widget.doctorId),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: Colors.white70,
              size: 22,
            ),
            onPressed: _logout,
            tooltip: 'Se déconnecter',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primary,
            child: Text(
              widget.doctorName[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Demandes en attente',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              )),
          ],
        ),
        const SizedBox(height: 10),
        ..._pending.map((req) => _buildPendingCard(req)),
      ],
    );
  }

  Widget _buildPendingCard(Map req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.orange.shade100,
            child: Text(
              (req['full_name'] ?? 'P')[0].toUpperCase(),
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req['full_name'] ?? 'Patient',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  )),
                Text(req['email'] ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGray,
                  )),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _respondToRequest(
                  req['id'], 'approved'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                    color: AppTheme.primary, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _respondToRequest(
                  req['id'], 'rejected'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                    color: Colors.red, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mes patients',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          )),
        const SizedBox(height: 10),
        _patients.isEmpty
          ? _buildEmptyPatients()
          : Column(
              children: _patients.map(
                (p) => _buildPatientCard(p)).toList(),
            ),
      ],
    );
  }

  Widget _buildEmptyPatients() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.people_outline,
            size: 48, color: AppTheme.textGray),
          SizedBox(height: 12),
          Text('Aucun patient pour l\'instant',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            )),
          SizedBox(height: 8),
          Text(
            'Vos patients apparaîtront ici\n'
            'une fois qu\'ils auront accepté votre accès',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textGray,
              fontSize: 13,
            )),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map patient) {
    final score = double.tryParse(
      patient['last_score']?.toString() ?? '0') ?? 0;
    final weight = double.tryParse(
      patient['last_weight']?.toString() ?? '0') ?? 0;
    final goal = patient['goal'];

    Color scoreColor = score >= 90
      ? Colors.green
      : score >= 70 ? Colors.orange : Colors.red;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatientDetailScreen(
            patientId:   patient['id'],
            patientName: patient['full_name'] ?? 'Patient',
            doctorId:    widget.doctorId,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: Text(
                (patient['full_name'] ?? 'P')[0].toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient['full_name'] ?? 'Patient',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppTheme.textDark,
                    )),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (weight > 0) ...[
                        Icon(Icons.monitor_weight_outlined,
                          size: 12, color: Colors.blue.shade400),
                        const SizedBox(width: 3),
                        Text('${weight.toInt()} kg',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                          )),
                        const SizedBox(width: 10),
                      ],
                      if (goal != null) ...[
                        Icon(Icons.flag_outlined,
                          size: 12, color: AppTheme.primary),
                        const SizedBox(width: 3),
                        Text(
                          goal == 'lose' ? 'Perte de poids'
                            : goal == 'gain' ? 'Prise de masse'
                            : 'Maintien',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textGray,
                          )),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                if (score > 0) ...[
                  Text('${score.toInt()}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    )),
                  Text('/100',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGray,
                    )),
                ] else
                  const Text('--',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textGray,
                    )),
                const Icon(Icons.chevron_right,
                  color: AppTheme.textGray, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}