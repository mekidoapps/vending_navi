import 'package:flutter/material.dart';

import '../models/vending_machine.dart';
import '../services/firestore_service.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({
    super.key,
    required this.machine,
  });

  final VendingMachine machine;

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  bool _isSubmitting = false;
  String? _selectedDrink;
  final TextEditingController _memoController = TextEditingController();

  List<String> get _products {
    final result = <String>[];
    final used = <String>{};

    for (final slot in widget.machine.drinkSlots) {
      final name = (slot['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final key = name.toLowerCase();
      if (used.contains(key)) continue;
      used.add(key);
      result.add(name);
    }

    return result;
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final drink = _selectedDrink?.trim();
    if (drink == null || drink.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final updatedDrinkSlots =
      widget.machine.drinkSlots.map((slot) {
        final name = (slot['name'] ?? '').toString().trim();
        if (name.isEmpty) return Map<String, dynamic>.from(slot);

        if (name == drink) {
          return <String, dynamic>{
            ...Map<String, dynamic>.from(slot),
            'name': name,
            'isSoldOut': false,
          };
        }

        return Map<String, dynamic>.from(slot);
      }).toList();

      final exists = updatedDrinkSlots.any(
            (slot) => ((slot['name'] ?? '').toString().trim() == drink),
      );

      if (!exists) {
        updatedDrinkSlots.add(<String, dynamic>{
          'name': drink,
          'manufacturer': null,
          'category': null,
          'isSoldOut': false,
        });
      }

      await FirestoreService.instance.checkin(
        machineId: widget.machine.id,
        drinkSlots: updatedDrinkSlots,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('チェックイン保存に失敗しました: $e'),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Widget _buildMachineHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.local_drink_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.machine.name,
                  style: const TextStyle(
                    fontFamily: 'Noto Sans JP',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                if ((widget.machine.address ?? '').trim().isNotEmpty)
                  Text(
                    widget.machine.address!,
                    style: const TextStyle(
                      fontFamily: 'Noto Sans JP',
                      fontSize: 13,
                      color: Color(0xFF60707A),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrinkSelector() {
    final products = _products;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '飲んだドリンク',
            style: TextStyle(
              fontFamily: 'Noto Sans JP',
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (products.isEmpty)
            const Text(
              '登録されているドリンクがありません',
              style: TextStyle(
                fontFamily: 'Noto Sans JP',
                fontSize: 13,
                color: Color(0xFF60707A),
              ),
            )
          else
            ...products.map((drink) {
              final selected = _selectedDrink == drink;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedDrink = drink;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFEAF6F7) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFFE3E7EB),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          drink,
                          style: TextStyle(
                            fontFamily: 'Noto Sans JP',
                            fontSize: 14,
                            fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                            color: const Color(0xFF1F2A30),
                          ),
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFF7A8791),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMemoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'メモ（任意）',
            style: TextStyle(
              fontFamily: 'Noto Sans JP',
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _memoController,
            maxLines: 3,
            style: const TextStyle(
              fontFamily: 'Noto Sans JP',
              fontSize: 14,
              color: Color(0xFF1F2A30),
            ),
            decoration: const InputDecoration(
              hintText: '例: ちゃんと補充されてた / 冷えてた / 行列なし',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;

    return Scaffold(
      appBar: AppBar(
        title: const Text('チェックイン'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
              (_selectedDrink == null || _isSubmitting || products.isEmpty)
                  ? null
                  : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(_isSubmitting ? '保存中...' : 'チェックインする'),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: <Widget>[
          _buildMachineHeader(),
          const SizedBox(height: 12),
          _buildDrinkSelector(),
          const SizedBox(height: 12),
          _buildMemoCard(),
        ],
      ),
    );
  }
}