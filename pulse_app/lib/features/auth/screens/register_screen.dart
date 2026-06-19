import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../profile/screens/profile_setup_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController        = TextEditingController();
  final _emailController       = TextEditingController();
  final _passwordController    = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _hospitalController    = TextEditingController();
  final _licenseController     = TextEditingController();
  final _bioController         = TextEditingController();

  bool _isLoading   = false;
  bool _showPass    = false;
  bool _showConfirm = false;
  bool _isDoctor    = false;
  String? _error;

  String?       _selectedSpeciality;
  PlatformFile? _cvFile;
  PlatformFile? _diplomaFile;

  static const _specialities = [
    'Nutritionniste', 'Médecin', 'Coach sportif',
    'Diététicien', 'Autre',
  ];

  Future<void> _pickPdf(bool isCV) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        if (isCV) {
          _cvFile = result.files.single;
        } else {
          _diplomaFile = result.files.single;
        }
      });
    }
  }

  Future<void> _register() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      final name    = _nameController.text.trim();
      final email   = _emailController.text.trim();
      final pass    = _passwordController.text;
      final confirm = _confirmPassController.text;

      if (name.isEmpty || email.isEmpty ||
          pass.isEmpty || confirm.isEmpty) {
        setState(() {
          _error = 'Veuillez remplir tous les champs obligatoires';
        });
        return;
      }
      if (pass.length < 6) {
        setState(() {
          _error = 'Mot de passe minimum 6 caractères';
        });
        return;
      }
      if (pass != confirm) {
        setState(() {
          _error = 'Les mots de passe ne correspondent pas';
        });
        return;
      }

      final data = <String, dynamic>{
        'firebase_uid': email,
        'email':        email,
        'full_name':    name,
        'role':         _isDoctor ? 'doctor' : 'user',
      };

      if (_isDoctor) {
        data['speciality']     = _selectedSpeciality;
        final hosp = _hospitalController.text.trim();
        final lic  = _licenseController.text.trim();
        final bio  = _bioController.text.trim();
        if (hosp.isNotEmpty) data['hospital']       = hosp;
        if (lic.isNotEmpty)  data['license_number'] = lic;
        if (bio.isNotEmpty)  data['bio']            = bio;
        if (_cvFile?.bytes != null) {
          data['cv_base64'] = base64Encode(_cvFile!.bytes!);
        }
        if (_diplomaFile?.bytes != null) {
          data['diploma_base64'] = base64Encode(_diplomaFile!.bytes!);
        }
      }

      final response = await ApiClient.dio.post(
        '/auth/register',
        data: data,
      );

      if (response.statusCode == 201) {
        if (_isDoctor) {
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
                title: const Row(children: [
                  Icon(Icons.check_circle,
                    color: Colors.green, size: 28),
                  SizedBox(width: 10),
                  Text('Compte créé !'),
                ]),
                content: const Text(
                  'Vos documents sont en cours de vérification par notre '
                  'équipe. Vous serez notifié par email dès que votre '
                  'compte sera approuvé.',
                  style: TextStyle(fontSize: 14),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Compris'),
                  ),
                ],
              ),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const LoginScreen()),
            );
          }
        } else {
          final user = response.data['user'];
          ApiClient.setUserId(user['firebase_uid']);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                  ProfileSetupScreen(userId: user['id'])),
            );
          }
        }
      }
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data['error']
          ?? 'Erreur lors de l\'inscription';
      });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Créer un compte'),
        backgroundColor: AppTheme.background,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bienvenue sur Pulse',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                )),
              const SizedBox(height: 8),
              const Text('Créez votre compte pour commencer',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textGray,
                )),
              const SizedBox(height: 24),

              // Toggle Utilisateur / Spécialiste
              _buildToggle(),
              const SizedBox(height: 24),

              // Champs communs
              _buildCommonFields(),

              // Champs spécialiste avec animation
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: _isDoctor
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
                firstChild: _buildDoctorFields(),
                secondChild: const SizedBox.shrink(),
              ),

              // Erreur
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                      color: AppTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontSize: 13,
                        )),
                    ),
                  ]),
                ),

              const SizedBox(height: 16),

              // Bouton submit
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: _isDoctor
                  ? ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B5BDB),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    )
                  : ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    ),
                child: _isLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                  : Text(_isDoctor
                    ? 'S\'inscrire comme spécialiste'
                    : 'S\'inscrire',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        _toggleBtn('Utilisateur', false),
        _toggleBtn('Spécialiste', true),
      ]),
    );
  }

  Widget _toggleBtn(String label, bool doctor) {
    final isActive = _isDoctor == doctor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isDoctor = doctor),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
              ? [BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2))]
              : null,
          ),
          child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive
                ? AppTheme.textDark
                : AppTheme.textGray,
            )),
        ),
      ),
    );
  }

  Widget _buildCommonFields() {
    return Column(children: [
      TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Nom complet',
          prefixIcon: Icon(Icons.person_outlined),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.email_outlined),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _passwordController,
        obscureText: !_showPass,
        decoration: InputDecoration(
          labelText: 'Mot de passe',
          prefixIcon: const Icon(Icons.lock_outlined),
          suffixIcon: IconButton(
            icon: Icon(_showPass
              ? Icons.visibility_off
              : Icons.visibility),
            onPressed: () =>
              setState(() => _showPass = !_showPass),
          ),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _confirmPassController,
        obscureText: !_showConfirm,
        decoration: InputDecoration(
          labelText: 'Confirmer le mot de passe',
          prefixIcon: const Icon(Icons.lock_outlined),
          suffixIcon: IconButton(
            icon: Icon(_showConfirm
              ? Icons.visibility_off
              : Icons.visibility),
            onPressed: () =>
              setState(() => _showConfirm = !_showConfirm),
          ),
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }

  Widget _buildDoctorFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 1,
          color: Colors.grey[200],
        ),

        // Spécialité
        const Text('Spécialité *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          )),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _specialities.map((s) {
            final isSelected = _selectedSpeciality == s;
            return GestureDetector(
              onTap: () =>
                setState(() => _selectedSpeciality = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                    ? AppTheme.primary
                    : AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                      ? AppTheme.primary
                      : AppTheme.primary.withOpacity(0.3)),
                ),
                child: Text(s,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected
                      ? Colors.white
                      : AppTheme.primary,
                    fontWeight: FontWeight.w500,
                  )),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Établissement / Clinique
        TextField(
          controller: _hospitalController,
          decoration: const InputDecoration(
            labelText: 'Établissement / Clinique (optionnel)',
            prefixIcon: Icon(Icons.local_hospital_outlined),
          ),
        ),
        const SizedBox(height: 16),

        // Numéro de licence
        TextField(
          controller: _licenseController,
          decoration: const InputDecoration(
            labelText: 'Numéro de licence (optionnel)',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 16),

        // Bio
        TextField(
          controller: _bioController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Bio courte (optionnel)',
            alignLabelWithHint: true,
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.info_outlined),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // CV PDF
        _buildFilePicker(
          label: 'Télécharger CV (PDF)',
          file: _cvFile,
          onTap: () => _pickPdf(true),
        ),
        const SizedBox(height: 12),

        // Diplôme PDF
        _buildFilePicker(
          label: 'Télécharger Diplôme (PDF)',
          file: _diplomaFile,
          onTap: () => _pickPdf(false),
        ),
        const SizedBox(height: 16),

        // Note vérification
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.amber.withOpacity(0.4)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outlined,
              color: Colors.amber, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Votre compte sera visible après vérification '
                'de vos documents',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.amber,
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFilePicker({
    required String label,
    required PlatformFile? file,
    required VoidCallback onTap,
  }) {
    final hasFile = file != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasFile
            ? Colors.green.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile
              ? Colors.green.withOpacity(0.4)
              : Colors.grey.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(
            hasFile ? Icons.check_circle : Icons.upload_file,
            color: hasFile ? Colors.green : AppTheme.textGray,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasFile ? file!.name : label,
              style: TextStyle(
                fontSize: 13,
                color: hasFile
                  ? Colors.green[700]
                  : AppTheme.textGray,
                fontWeight: hasFile
                  ? FontWeight.w500
                  : FontWeight.normal,
              ),
            ),
          ),
          if (!hasFile)
            const Icon(Icons.chevron_right,
              color: AppTheme.textGray, size: 20),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPassController.dispose();
    _hospitalController.dispose();
    _licenseController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
