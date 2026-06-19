import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class PhotoAnalysisScreen extends StatefulWidget {
  final String userId;
  const PhotoAnalysisScreen({super.key, required this.userId});

  @override
  State<PhotoAnalysisScreen> createState() =>
    _PhotoAnalysisScreenState();
}

class _PhotoAnalysisScreenState
    extends State<PhotoAnalysisScreen> {
  File?   _image;
  Map?    _result;
  bool    _isAnalyzing = false;
  String? _error;

  Future<void> _pickAndAnalyze(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final photo  = await picker.pickImage(
        source:       source,
        imageQuality: 70,
        maxWidth:     1024,
      );
      if (photo == null) return;

      setState(() {
        _image       = File(photo.path);
        _isAnalyzing = true;
        _result      = null;
        _error       = null;
      });

      final bytes     = await _image!.readAsBytes();
      final base64Img = base64Encode(bytes);

      final response = await ApiClient.dio.post(
        '/meals/analyze-photo',
        data: {
          'image_base64': base64Img,
          'mime_type':    'image/jpeg',
        },
      );

      setState(() {
        _result      = response.data['food'];
        _isAnalyzing = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error       = e.response?.data['error']
          ?? 'Erreur lors de l\'analyse';
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _error       = 'Erreur: ${e.toString()}';
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _addToMeal(String mealType) async {
    if (_result == null) return;
    try {
      await ApiClient.dio.post('/meals', data: {
        'user_id':   widget.userId,
        'meal_type': mealType,
        'items': [
          {
            'food_name': _result!['food_name'],
            'source':    _result!['source'] ?? 'kimi',
            'quantity_g': _result!['portion_g'] ?? 300,
            'calories':   _result!['calories']  ?? 0,
            'protein_g':  _result!['protein_g'] ?? 0,
            'carbs_g':    _result!['carbs_g']   ?? 0,
            'fat_g':      _result!['fat_g']     ?? 0,
          }
        ],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Repas ajouté au journal !'),
            backgroundColor: AppTheme.primary,
          ),
        );
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMealSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ajouter à quel repas ?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              )),
            const SizedBox(height: 16),
            _mealBtn('breakfast', 'Petit-déjeuner',
              Icons.wb_sunny_outlined,      Colors.orange),
            const SizedBox(height: 8),
            _mealBtn('lunch', 'Déjeuner',
              Icons.lunch_dining_outlined,  Colors.green),
            const SizedBox(height: 8),
            _mealBtn('dinner', 'Dîner',
              Icons.dinner_dining_outlined, Colors.indigo),
            const SizedBox(height: 8),
            _mealBtn('snack', 'Snack',
              Icons.apple_outlined,         Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _mealBtn(String type, String label,
      IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _addToMeal(type);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              )),
          ],
        ),
      ),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt,
                color: AppTheme.primary),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndAnalyze(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library,
                color: AppTheme.primary),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickAndAnalyze(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Badge source
  Widget _buildSourceBadge(String? source) {
    Color  bgColor;
    Color  textColor;
    String label;

    switch (source) {
      case 'foods_tn':
        bgColor   = Colors.green.shade50;
        textColor = Colors.green.shade700;
        label     = 'Base TN';
        break;
      case 'gemini':
        bgColor   = Colors.purple.shade50;
        textColor = Colors.purple.shade700;
        label     = 'Gemini AI';
        break;
      default:
        bgColor   = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        label     = 'IA';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        )),
    );
  }

  // Badge confiance
  Widget _confidenceBadge(String confidence) {
    Color  color;
    String label;
    switch (confidence) {
      case 'high':
        color = Colors.green;  label = 'Haute';   break;
      case 'medium':
        color = Colors.orange; label = 'Moyenne'; break;
      default:
        color = Colors.red;    label = 'Faible';
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        )),
    );
  }

  Widget _macroCard(String label, dynamic value,
      String emoji, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textGray,
                  )),
                Text(emoji,
                  style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${(value as num?)?.toStringAsFixed(1) ?? '0'} g',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Analyser un repas'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // Zone photo
            GestureDetector(
              onTap: _showPhotoOptions,
              child: Container(
                width: double.infinity,
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _image != null
                      ? AppTheme.primary
                      : Colors.grey.shade200,
                    width: _image != null ? 2 : 1,
                  ),
                ),
                child: _image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        _image!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment:
                        MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined,
                          size: 48,
                          color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Prendre une photo ou',
                          style: TextStyle(
                            color: AppTheme.textGray,
                            fontSize: 15,
                          )),
                        const Text(
                          'choisir depuis la galerie',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          )),
                      ],
                    ),
              ),
            ),

            const SizedBox(height: 16),

            // Boutons caméra / galerie
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                      _pickAndAnalyze(ImageSource.camera),
                    icon: const Icon(
                      Icons.camera_alt, size: 18),
                    label: const Text('Caméra'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                          BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                      _pickAndAnalyze(ImageSource.gallery),
                    icon: const Icon(
                      Icons.photo_library, size: 18),
                    label: const Text('Galerie'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(
                        color: AppTheme.primary),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                          BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Chargement
            if (_isAnalyzing)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      color: AppTheme.primary),
                    const SizedBox(height: 12),
                    const Text('Analyse en cours...',
                      style: TextStyle(
                        color: AppTheme.textGray,
                        fontSize: 15,
                      )),
                    const SizedBox(height: 4),
                    Text(
                      'Kimi Vision identifie votre plat',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      )),
                  ],
                ),
              ),

            // Erreur
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                      color: Colors.red.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                        style: TextStyle(
                          color: Colors.red.shade600)),
                    ),
                  ],
                ),
              ),

            // Résultat
            if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment:
                    CrossAxisAlignment.start,
                  children: [

                    // Nom + badge source
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                              CrossAxisAlignment.start,
                            children: [
                              Text(
                                _result!['food_name']
                                  ?? 'Plat inconnu',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              if (_result!['food_name_ar']
                                  != null)
                                Text(
                                  _result!['food_name_ar'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textGray,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _buildSourceBadge(
                          _result!['source']),
                      ],
                    ),

                    const SizedBox(height: 6),

                    if (_result!['notes'] != null)
                      Text(
                        _result!['notes'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textGray,
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Calories
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary
                          .withOpacity(0.05),
                        borderRadius:
                          BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.primary
                            .withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Text('🔥',
                            style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                    '${(_result!['calories']
                                      as num?)?.toInt() ?? 0}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight:
                                      FontWeight.bold,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' kcal',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '~${(_result!['portion_g']
                              as num?)?.toInt() ?? 300} g',
                            style: const TextStyle(
                              color: AppTheme.textGray,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Macros
                    Row(
                      children: [
                        _macroCard('Protéines',
                          _result!['protein_g'],
                          '🍗', Colors.blue),
                        const SizedBox(width: 8),
                        _macroCard('Glucides',
                          _result!['carbs_g'],
                          '🌾', Colors.orange),
                        const SizedBox(width: 8),
                        _macroCard('Lipides',
                          _result!['fat_g'],
                          '🫙', Colors.red),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Confiance
                    Row(
                      children: [
                        const Text('Précision : ',
                          style: TextStyle(
                            color: AppTheme.textGray,
                            fontSize: 12,
                          )),
                        _confidenceBadge(
                          _result!['confidence'] ?? 'low'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Boutons action
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showPhotoOptions,
                      icon: const Icon(
                        Icons.refresh, size: 18),
                      label: const Text('Réanalyser'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(
                          color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                            BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _showMealSelector,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter au journal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                            BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}