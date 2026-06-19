import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RulerPickerSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final double initialValue;
  final double minValue;
  final double maxValue;
  final double step;
  final String unit;
  final Function(double) onDone;

  const RulerPickerSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.initialValue,
    required this.minValue,
    required this.maxValue,
    this.step = 1,
    required this.unit,
    required this.onDone,
  });

  @override
  State<RulerPickerSheet> createState() => _RulerPickerSheetState();
}

class _RulerPickerSheetState extends State<RulerPickerSheet> {
  late double _value;
  late ScrollController _scrollController;
  final double _itemExtent = 20.0;

  int get _totalItems =>
    ((widget.maxValue - widget.minValue) / widget.step).round() + 1;

  double _indexToValue(int index) =>
    widget.minValue + index * widget.step;

  int _valueToIndex(double value) =>
    ((value - widget.minValue) / widget.step).round();

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    final initialIndex = _valueToIndex(widget.initialValue);
    _scrollController = ScrollController(
      initialScrollOffset: initialIndex * _itemExtent,
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final index =
      (_scrollController.offset / _itemExtent).round();
    final clamped = index.clamp(0, _totalItems - 1);
    final newValue = _indexToValue(clamped);
    if (newValue != _value) {
      HapticFeedback.selectionClick();
      setState(() => _value = newValue);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24)),
      ),
      child: Column(
        children: [

          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Bouton fermer
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(
                right: 16, top: 12),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                    size: 18, color: Colors.black54),
                ),
              ),
            ),
          ),

          // Titre
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24),
            child: Column(
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Règle + valeur
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // Règle à défilement
                SizedBox(
                  width: 160,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _totalItems,
                    itemExtent: _itemExtent,
                    reverse: true,
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.22,
                    ),
                    itemBuilder: (context, i) {
                      final val = _indexToValue(i);
                      final isMajor =
                        (val % (widget.step * 5)) == 0;
                      final isSelected = val == _value;

                      return Row(
                        mainAxisAlignment:
                          MainAxisAlignment.end,
                        children: [
                          if (isMajor)
                            Padding(
                              padding: const EdgeInsets
                                .only(right: 8),
                              child: Text(
                                val.toInt().toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                    ? Colors.black
                                    : Colors.grey.shade400,
                                ),
                              ),
                            ),
                          Container(
                            width: isMajor ? 32 : 20,
                            height: 1.5,
                            color: isSelected
                              ? Colors.red.shade300
                              : isMajor
                                ? Colors.grey.shade400
                                : Colors.grey.shade300,
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(width: 24),

                // Valeur affichée
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _value.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          height: 1,
                        ),
                      ),
                      TextSpan(
                        text: ' ${widget.unit}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bouton Enregistrer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDone(_value);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text(
                  'Enregistrer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Fonction helper
Future<void> showRulerPicker({
  required BuildContext context,
  required String title,
  required String subtitle,
  required double initialValue,
  required double minValue,
  required double maxValue,
  double step = 1,
  required String unit,
  required Function(double) onDone,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RulerPickerSheet(
      title: title,
      subtitle: subtitle,
      initialValue: initialValue,
      minValue: minValue,
      maxValue: maxValue,
      step: step,
      unit: unit,
      onDone: onDone,
    ),
  );
}