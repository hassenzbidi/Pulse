import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../doctor/screens/doctor_dashboard_screen.dart';
import 'register_screen.dart';
import '../../admin/screens/admin_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPass  = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      final email = _emailController.text.trim();

      if (email.isEmpty || _passwordController.text.isEmpty) {
        setState(() {
          _error = 'Veuillez remplir tous les champs';
        });
        return;
      }

      final response = await ApiClient.dio.get(
        '/auth/me',
        queryParameters: {'firebase_uid': email},
      );

      if (response.statusCode == 200) {
        final user = response.data['user'];
        ApiClient.setUserId(user['firebase_uid']);

        if (mounted) {
          if (user['role'] == 'doctor') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DoctorDashboardScreen(
                  doctorId:   user['id'],
                  doctorName: user['full_name'] ?? 'Médecin',
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DashboardScreen(
                  userId: user['id'],
                ),
              ),
            );
          }
        }
      }
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data['error']
          ?? 'Erreur de connexion';
      });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // Logo et titre
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Pulse',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Votre coach nutritionnel intelligent',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textGray,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              const Text(
                'Connexion',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 24),

              // Champ email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Champ mot de passe
              TextField(
                controller: _passwordController,
                obscureText: !_showPass,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPass
                        ? Icons.visibility_off
                        : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() { _showPass = !_showPass; });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Message d'erreur
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                        color: AppTheme.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Bouton connexion
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Se connecter'),
              ),

              const SizedBox(height: 16),

              // Lien inscription
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: RichText(
                    text: const TextSpan(
                      text: 'Pas encore de compte ? ',
                      style: TextStyle(
                        color: AppTheme.textGray),
                      children: [
                        TextSpan(
                          text: 'S\'inscrire',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

// Accès admin caché
GestureDetector(
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const AdminLoginScreen(),
    ),
  ),
  child: const Text(
    'Administration',
    style: TextStyle(
      fontSize: 11,
      color: Colors.transparent,
    ),
  ),
),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}