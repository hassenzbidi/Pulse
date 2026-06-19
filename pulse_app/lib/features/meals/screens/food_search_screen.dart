import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class FoodSearchScreen extends StatefulWidget {
  final String userId;
  final String mealType;
  const FoodSearchScreen({
    super.key,
    required this.userId,
    required this.mealType,
  });

  @override
  State<FoodSearchScreen> createState() =>
    _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _searchCtrl = TextEditingController();
  List  _results    = [];
  bool  _isLoading  = false;
  bool  _isAdding   = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results = []; });
      return;
    }
    setState(() { _isLoading = true; });
    try {
      // Chercher dans foods_tn d'abord
      final localRes = await ApiClient.dio.get(
        '/foods/search',
        queryParameters: { 'q': query },
      );
      final local = (localRes.data['foods'] as List)
        .map((f) => { ...f, 'source': 'foods_tn' })
        .toList();

      // Chercher aussi dans Open Food Facts
      List off = [];
      try {
        final offRes = await ApiClient.dio.get(
          '/meals/search-food',
          queryParameters: { 'q': query },
        );
        off = (offRes.data['foods'] as List? ?? [])
          .map((f) => { ...f, 'source': 'openfoodfacts' })
          .toList();
      } catch (_) {}

      setState(() {
        _results  = [...local, ...off];
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _addFood(Map food, double quantity) async {
    setState(() { _isAdding = true; });
    try {
      final factor = quantity / 100;
      await ApiClient.dio.post('/meals', data: {
        'user_id':   widget.userId,
        'meal_type': widget.mealType,
        'items': [
          {
            'food_name': food['name_fr']
              ?? food['food_name']
              ?? 'Aliment',
            'source':    food['source'] ?? 'manual',
            'quantity_g': quantity,
            'calories':
              ((double.tryParse(food['calories']
                ?.toString() ?? '0') ?? 0) * factor),
            'protein_g':
              ((double.tryParse(food['protein_g']
                ?.toString() ?? '0') ?? 0) * factor),
            'carbs_g':
              ((double.tryParse(food['carbs_g']
                ?.toString() ?? '0') ?? 0) * factor),
            'fat_g':
              ((double.tryParse(food['fat_g']
                ?.toString() ?? '0') ?? 0) * factor),
          }
        ],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aliment ajouté au journal !'),
            backgroundColor: AppTheme.primary,
          ),
        );
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      setState(() { _isAdding = false; });
    }
  }

  void _showQuantityDialog(Map food) {
    final ctrl = TextEditingController(text: '100');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        title: Text(
          food['name_fr'] ?? food['food_name'] ?? 'Aliment',
          style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Infos pour 100g
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment:
                  MainAxisAlignment.spaceAround,
                children: [
                  _miniMacro('Cal',
                    '${double.tryParse(food['calories']
                      ?.toString() ?? '0')?.toInt() ?? 0}',
                    Colors.orange),
                  _miniMacro('Prot',
                    '${double.tryParse(food['protein_g']
                      ?.toString() ?? '0')?.toInt() ?? 0}g',
                    Colors.blue),
                  _miniMacro('Glu',
                    '${double.tryParse(food['carbs_g']
                      ?.toString() ?? '0')?.toInt() ?? 0}g',
                    Colors.green),
                  _miniMacro('Lip',
                    '${double.tryParse(food['fat_g']
                      ?.toString() ?? '0')?.toInt() ?? 0}g',
                    Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('Pour 100g',
              style: TextStyle(
                fontSize: 11, color: AppTheme.textGray)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantité',
                suffixText: 'g',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primary, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler',
              style: TextStyle(color: AppTheme.textGray)),
          ),
          ElevatedButton(
            onPressed: () {
              final q = double.tryParse(ctrl.text) ?? 100;
              Navigator.pop(context);
              _addFood(food, q);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Widget _miniMacro(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          )),
        Text(label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textGray,
          )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Rechercher un aliment'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Couscous, lablabi, poulet...',
                prefixIcon: const Icon(Icons.search,
                  color: AppTheme.textGray),
                suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                        color: AppTheme.textGray),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() { _results = []; });
                      },
                    )
                  : null,
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Résultats
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator(
                  color: AppTheme.primary))
              : _results.isEmpty
                ? _searchCtrl.text.isEmpty
                  ? _buildSuggestions()
                  : const Center(
                      child: Text('Aucun résultat',
                        style: TextStyle(
                          color: AppTheme.textGray)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _results.length,
                    itemBuilder: (_, i) =>
                      _buildFoodItem(_results[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Suggestions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            )),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Couscous', 'Lablabi', 'Brik',
              'Chorba', 'Poulet', 'Salade',
              'Riz', 'Pâtes', 'Yaourt',
            ].map((s) => GestureDetector(
              onTap: () {
                _searchCtrl.text = s;
                _search(s);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(s,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  )),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(Map food) {
    final name = food['name_fr']
      ?? food['food_name']
      ?? 'Aliment';
    final cal  = double.tryParse(
      food['calories']?.toString() ?? '0') ?? 0;
    final source = food['source'];
    final isTN   = source == 'foods_tn';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isTN
              ? AppTheme.primary.withOpacity(0.1)
              : Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              isTN ? '🇹🇳' : '🌍',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Text(name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppTheme.textDark,
          )),
        subtitle: Row(
          children: [
            Text('${cal.toInt()} kcal / 100g',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textGray,
              )),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isTN
                  ? AppTheme.primary.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isTN ? 'Base TN' : 'Mondial',
                style: TextStyle(
                  fontSize: 10,
                  color: isTN
                    ? AppTheme.primary
                    : Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                )),
            ),
          ],
        ),
        trailing: GestureDetector(
          onTap: () => _showQuantityDialog(food),
          child: Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add,
              color: Colors.white, size: 20),
          ),
        ),
        onTap: () => _showQuantityDialog(food),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}