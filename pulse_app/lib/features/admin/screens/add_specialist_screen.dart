import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class AddSpecialistScreen extends StatefulWidget {
  const AddSpecialistScreen({super.key});

  @override
  State<AddSpecialistScreen> createState() =>
    _AddSpecialistScreenState();
}

class _AddSpecialistScreenState
    extends State<AddSpecialistScreen> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _specialCtrl  = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  final _licenseCtrl  = TextEditingController();
  final _bioCtrl      = TextEditingController();
  bool    _isLoading  = false;
  String? _error;

  Future<void> _addSpecialist() async {
    if (_nameCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _specialCtrl.text.isEmpty) {
      setState(() {
        _error = 'Nom, email et spécialité sont requis';
      });
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final response = await ApiClient.dio.post(
        '/admin/add-specialist',
        data: {
          'full_name':      _nameCtrl.text.trim(),
          'email':          _emailCtrl.text.trim(),
          'speciality':     _specialCtrl.text.trim(),
          'hospital':       _hospitalCtrl.text.trim(),
          'license_number': _licenseCtrl.text.trim(),
          'bio':            _bioCtrl.text.trim(),
        },
        options: Options(headers: ApiClient.adminHeaders),
      );

      final password = response.data['password_temp'] ?? '';

      setState(() { _isLoading = false; });

      _nameCtrl.clear();
      _emailCtrl.clear();
      _specialCtrl.clear();
      _hospitalCtrl.clear();
      _licenseCtrl.clear();
      _bioCtrl.clear();

      if (mounted) _showPasswordDialog(password);

    } on DioException catch (e) {
      setState(() {
        _error     = e.response?.data['error']
          ?? 'Erreur lors de l\'ajout';
        _isLoading = false;
      });
    }
  }

  void _showPasswordDialog(String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline,
                color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Mot de passe généré',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                )),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Communiquez ce mot de passe au spécialiste.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textGray,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      password,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy,
                      color: AppTheme.primary, size: 20),
                    tooltip: 'Copier',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: password));
                      if (mounted) {
                        ScaffoldMessenger.of(context)
                          .showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Mot de passe copié !'),
                            backgroundColor: AppTheme.primary,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer',
              style: TextStyle(color: AppTheme.textGray)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copier & Fermer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: password));
              if (mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Ajouter un spécialiste'),
        backgroundColor: const Color(0xFF1A2E2A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                    color: AppTheme.primary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Le spécialiste sera automatiquement '
                      'vérifié et visible pour les patients.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                      )),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Formulaire
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Informations personnelles',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    )),
                  const SizedBox(height: 12),
                  _buildField(_nameCtrl,
                    'Nom complet *',
                    Icons.person_outlined),
                  const SizedBox(height: 12),
                  _buildField(_emailCtrl,
                    'Email *',
                    Icons.email_outlined,
                    type: TextInputType.emailAddress),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Informations professionnelles',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    )),
                  const SizedBox(height: 12),

                  // Spécialité avec chips
                  const Text('Spécialité *',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textGray,
                    )),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      'Nutritionniste',
                      'Médecin',
                      'Coach sportif',
                      'Diététicien',
                    ].map((s) => GestureDetector(
                      onTap: () {
                        _specialCtrl.text = s;
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _specialCtrl.text == s
                            ? AppTheme.primary
                            : AppTheme.primary
                                .withOpacity(0.08),
                          borderRadius:
                            BorderRadius.circular(20),
                        ),
                        child: Text(s,
                          style: TextStyle(
                            fontSize: 12,
                            color: _specialCtrl.text == s
                              ? Colors.white
                              : AppTheme.primary,
                            fontWeight: FontWeight.w500,
                          )),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 8),
                  _buildField(_specialCtrl,
                    'Ou saisir une spécialité',
                    Icons.medical_services_outlined),

                  const SizedBox(height: 12),
                  _buildField(_hospitalCtrl,
                    'Établissement / Clinique',
                    Icons.local_hospital_outlined),
                  const SizedBox(height: 12),
                  _buildField(_licenseCtrl,
                    'Numéro de licence',
                    Icons.badge_outlined),
                  const SizedBox(height: 12),
                  _buildField(_bioCtrl,
                    'Bio / Description',
                    Icons.description_outlined,
                    maxLines: 3),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Messages
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.red.shade200)),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                      color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 13,
                        ))),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Bouton ajouter
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _addSpecialist,
                icon: _isLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.add, size: 20),
                label: const Text('Ajouter le spécialiste',
                  style: TextStyle(fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller:  ctrl,
      keyboardType: type,
      maxLines:    maxLines,
      onChanged:   (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon,
          color: AppTheme.textGray, size: 20),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppTheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _specialCtrl.dispose();
    _hospitalCtrl.dispose();
    _licenseCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }
}