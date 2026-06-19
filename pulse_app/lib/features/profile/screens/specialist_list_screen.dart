import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../chat/screens/discussion_screen.dart';

class SpecialistListScreen extends StatefulWidget {
  final String patientId;
  const SpecialistListScreen({super.key, required this.patientId});

  @override
  State<SpecialistListScreen> createState() =>
      _SpecialistListScreenState();
}

class _SpecialistListScreenState
    extends State<SpecialistListScreen> {
  List              _doctors      = [];
  bool              _isLoading    = true;
  Map<String,String> _accessStatus = {};   // doctor_id → status
  final Set<String> _sending      = {};
  final Set<String> _sent         = {};
  final Set<String> _revoking     = {};

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() { _isLoading = true; });
    try {
      final results = await Future.wait([
        ApiClient.dio.get('/doctor/list'),
        ApiClient.dio.get(
          '/doctor/access-status/${widget.patientId}'),
      ]);
      final doctors  = results[0].data['doctors']  as List? ?? [];
      final accesses = results[1].data['accesses'] as List? ?? [];

      final statusMap = <String, String>{};
      for (final a in accesses) {
        final did = a['doctor_id']?.toString() ?? '';
        if (did.isNotEmpty) {
          statusMap[did] = a['status']?.toString() ?? '';
        }
      }

      setState(() {
        _doctors      = doctors;
        _accessStatus = statusMap;
        _isLoading    = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement : $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _sendRequest(String doctorId) async {
    setState(() { _sending.add(doctorId); });
    try {
      await ApiClient.dio.post(
        '/doctor/request',
        data: {
          'patient_id': widget.patientId,
          'doctor_id':  doctorId,
        },
      );
      setState(() {
        _sending.remove(doctorId);
        _sent.add(doctorId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle,
                    color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Demande envoyée au spécialiste.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primary,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() { _sending.remove(doctorId); });
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

  Future<void> _revokeAccess(
      String doctorId, String doctorName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler le suivi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          )),
        content: Text(
          'Voulez-vous retirer Dr. $doctorName de votre '
          'liste de suivi ? Cette action est réversible.',
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textGray,
          )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
              style: TextStyle(color: AppTheme.textGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() { _revoking.add(doctorId); });
    try {
      await ApiClient.dio.patch(
        '/doctor/access/${widget.patientId}',
        data: {
          'doctor_id': doctorId,
          'status':    'revoked',
        },
      );
      setState(() {
        _revoking.remove(doctorId);
        _doctors.removeWhere(
          (d) => d['id']?.toString() == doctorId);
        _accessStatus.remove(doctorId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suivi annulé avec succès.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() { _revoking.remove(doctorId); });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Spécialistes disponibles'),
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDoctors,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary))
          : _doctors.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _loadDoctors,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _doctors.length,
                    itemBuilder: (_, i) =>
                        _buildDoctorCard(_doctors[i]),
                  ),
                ),
    );
  }

  Widget _buildDoctorCard(Map doctor) {
    final id         = doctor['id']?.toString() ?? '';
    final name       = doctor['full_name']
        ?? doctor['name']
        ?? 'Médecin';
    final specialty  = doctor['specialty']
        ?? doctor['speciality']
        ?? '';
    final hospital   = doctor['hospital']  ?? '';
    final isSending  = _sending.contains(id);
    final isSent     = _sent.contains(id);
    final isRevoking = _revoking.contains(id);
    final serverStatus = _accessStatus[id] ?? '';
    final isApproved = serverStatus == 'approved';
    final isPending  = serverStatus == 'pending';
    final initial    = name.isNotEmpty
        ? name[0].toUpperCase() : 'M';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor:
                  AppTheme.primary.withOpacity(0.12),
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Infos + bouton
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  if (specialty.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.medical_services_outlined,
                          size: 14,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            specialty,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (hospital.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_hospital_outlined,
                          size: 14,
                          color: AppTheme.textGray,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hospital,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textGray,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (isApproved) ...[
                    // Badge "Suivi actif"
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.green.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                            color: Colors.green.shade600,
                            size: 14),
                          const SizedBox(width: 4),
                          Text('Suivi actif',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Bouton Discuter
                    SizedBox(
                      height: 38,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DiscussionScreen(
                              currentUserId: widget.patientId,
                              otherUserId:   id,
                              otherName:     name,
                              otherRole:     'doctor',
                            ),
                          ),
                        ),
                        icon: const Icon(
                          Icons.chat_outlined, size: 16),
                        label: const Text('Discuter'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(
                            color: AppTheme.primary),
                          minimumSize:
                            const Size(double.infinity, 38),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                              BorderRadius.circular(10)),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Bouton Annuler (rouge)
                    SizedBox(
                      height: 38,
                      child: ElevatedButton.icon(
                        onPressed: isRevoking
                            ? null
                            : () => _revokeAccess(id, name),
                        icon: isRevoking
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.close, size: 16),
                        label: const Text('Annuler'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          minimumSize:
                            const Size(double.infinity, 38),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                              BorderRadius.circular(10)),
                          elevation: 0,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else if (isSent || isPending) ...[
                    // Confirmation envoi + bouton Discuter
                    Row(
                      children: [
                        Icon(
                          isPending
                            ? Icons.hourglass_top
                            : Icons.check_circle,
                          color: AppTheme.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPending
                            ? 'En attente de réponse'
                            : 'Demande envoyée',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                          )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DiscussionScreen(
                              currentUserId: widget.patientId,
                              otherUserId:   id,
                              otherName:     name,
                              otherRole:     'doctor',
                            ),
                          ),
                        ),
                        icon: const Icon(
                          Icons.chat_outlined, size: 16),
                        label: const Text('Discuter'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(
                            color: AppTheme.primary),
                          minimumSize:
                            const Size(double.infinity, 38),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                              BorderRadius.circular(10)),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: isSending
                            ? null
                            : () => _sendRequest(id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.white,
                          minimumSize:
                            const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                              BorderRadius.circular(10)),
                          elevation: 0,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: isSending
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.white,
                                ),
                              )
                            : const Text('Envoyer une demande'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline,
              size: 40,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun spécialiste disponible',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Revenez plus tard',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textGray,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadDoctors,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(160, 44),
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
