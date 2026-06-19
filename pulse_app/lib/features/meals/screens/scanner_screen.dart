import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class ScannerScreen extends StatefulWidget {
  final String userId;
  const ScannerScreen({super.key, required this.userId});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool   _isScanning  = true;
  bool   _isLoading   = false;
  Map?   _foodResult;
  String? _error;

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (!_isScanning) return;
    final barcode = capture.barcodes.first.rawValue;
    if (barcode == null) return;

    setState(() {
      _isScanning = false;
      _isLoading  = true;
      _error      = null;
    });

    try {
      final response = await ApiClient.dio.get('/meals/scan/$barcode');
      setState(() {
        _foodResult = response.data['food'];
        _isLoading  = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error     = e.response?.data['error'] ?? 'Produit non trouvé';
        _isLoading = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _isScanning = true;
      _foodResult = null;
      _error      = null;
    });
  }

  Future<void> _addToMeal(String mealType) async {
  if (_foodResult == null) return;
  try {
    await ApiClient.dio.post('/meals', data: {
      'user_id':   widget.userId,
      'meal_type': mealType,
      'items': [
        {
          'food_name': _foodResult!['food_name'],
          'source':    'openfoodfacts',
          'barcode':   _foodResult!['barcode'],
          'quantity_g': 100,
          'calories':  _foodResult!['calories'],
          'protein_g': _foodResult!['protein_g'],
          'carbs_g':   _foodResult!['carbs_g'],
          'fat_g':     _foodResult!['fat_g'],
        }
      ],
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Ajouté au journal !'),
          backgroundColor: AppTheme.primary,
          duration: Duration(seconds: 2),
        ),
      );
      // Retourner au dashboard au lieu de pop
      Navigator.of(context).popUntil((route) => route.isFirst);
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

  void _showMealTypeSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
            _mealTypeButton('breakfast', 'Petit-déjeuner',
              Icons.wb_sunny_outlined, Colors.orange),
            const SizedBox(height: 8),
            _mealTypeButton('lunch', 'Déjeuner',
              Icons.lunch_dining_outlined, Colors.green),
            const SizedBox(height: 8),
            _mealTypeButton('dinner', 'Dîner',
              Icons.dinner_dining_outlined, Colors.indigo),
            const SizedBox(height: 8),
            _mealTypeButton('snack', 'Snack',
              Icons.apple_outlined, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _mealTypeButton(String type, String label,
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

  // Calcul score nutritionnel simple
  int _calcNutriScore(Map food) {
    final cal  = double.tryParse(food['calories']?.toString()  ?? '0') ?? 0;
    final prot = double.tryParse(food['protein_g']?.toString() ?? '0') ?? 0;
    final fat  = double.tryParse(food['fat_g']?.toString()     ?? '0') ?? 0;
    int score = 50;
    if (cal < 200) score += 20;
    else if (cal > 400) score -= 20;
    if (prot > 10) score += 15;
    if (fat > 20) score -= 15;
    return score.clamp(0, 100);
  }

  String _scoreLabel(int score) {
    if (score >= 70) return 'Excellent';
    if (score >= 50) return 'Correct';
    if (score >= 30) return 'Pas idéal';
    return 'À éviter';
  }

  Color _scoreColor(int score) {
    if (score >= 70) return Colors.green;
    if (score >= 50) return Colors.lightGreen;
    if (score >= 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (_foodResult != null) {
      return _buildResultScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scanner un produit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onBarcodeDetected,
          ),
          if (_isScanning && !_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppTheme.primary, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Pointez vers le code barre',
                      style: TextStyle(
                        color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppTheme.primary),
                    SizedBox(height: 16),
                    Text('Recherche du produit...',
                      style: TextStyle(
                        color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
          if (_error != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                      color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!,
                      style: const TextStyle(
                        color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _reset,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    final food  = _foodResult!;
    final cal   = double.tryParse(food['calories']?.toString()  ?? '0') ?? 0;
    final prot  = double.tryParse(food['protein_g']?.toString() ?? '0') ?? 0;
    final carbs = double.tryParse(food['carbs_g']?.toString()   ?? '0') ?? 0;
    final fat   = double.tryParse(food['fat_g']?.toString()     ?? '0') ?? 0;
    final score = _calcNutriScore(food);
    final now   = DateTime.now();
    final time  = '${now.day} May at '
                  '${now.hour.toString().padLeft(2,'0')}:'
                  '${now.minute.toString().padLeft(2,'0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [

                    // Header carte
                    Container(
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
                              GestureDetector(
                                onTap: _reset,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_back,
                                    size: 20),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Text('100 g',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      )),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit,
                                      size: 14,
                                      color: AppTheme.textGray),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            food['food_name'] ?? 'Produit inconnu',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Snack · $time',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textGray,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _actionChip(
                                Icons.auto_awesome_outlined,
                                'Ask',
                              ),
                              const SizedBox(width: 8),
                              _actionChip(
                                Icons.star_border,
                                'Favoris',
                              ),
                              const SizedBox(width: 8),
                              _actionChip(
                                Icons.delete_outline,
                                'Supprimer',
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Calories et nutriments
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Calories et nutriments',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textGray,
                            )),
                          const SizedBox(height: 12),

                          // Calories
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                const Text('🔥',
                                  style: TextStyle(fontSize: 24)),
                                const SizedBox(width: 12),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${cal.toInt()} ',
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: 'calories',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: AppTheme.textGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Macros
                          Row(
                            children: [
                              _macroCard('Glucides', carbs, '🌾'),
                              const SizedBox(width: 8),
                              _macroCard('Protéines', prot, '🍗'),
                              const SizedBox(width: 8),
                              _macroCard('Lipides', fat, '🫙'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Score nutritionnel
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Score nutritionnel',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textGray,
                            )),
                          const SizedBox(height: 8),
                          Text(
                            _scoreLabel(score),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Container(
                                height: 16,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.red,
                                      Colors.orange,
                                      Colors.yellow,
                                      Colors.lightGreen,
                                      Colors.green,
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: (score / 100) *
                                  (MediaQuery.of(context).size.width - 64)
                                  - 16,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _scoreColor(score),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$score',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _scoreColor(score),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Ingrédients
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Ingrédients',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textGray,
                                )),
                              TextButton.icon(
                                onPressed: _showMealTypeSelector,
                                icon: const Icon(Icons.add,
                                  size: 16,
                                  color: AppTheme.primary),
                                label: const Text('Ajouter plus',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 13,
                                  )),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('🍫', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  food['food_name'] ?? 'Produit',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ),
                              Text(
                                '${cal.toInt()} cal',
                                style: const TextStyle(
                                  color: AppTheme.textGray,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text('100 g',
                                style: TextStyle(
                                  color: AppTheme.textGray,
                                  fontSize: 13,
                                )),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Boutons bas
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              color: const Color(0xFFF2F2F7),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.qr_code_scanner,
                        size: 18),
                      label: const Text('Rescanner'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(
                          color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _showMealTypeSelector,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter au repas'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE05555),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      ),
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

  Widget _actionChip(IconData icon, String label,
      {Color color = AppTheme.textGray}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            )),
        ],
      ),
    );
  }

  Widget _macroCard(String label, double value, String emoji) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
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
                  style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${value.toStringAsFixed(1)} g',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}