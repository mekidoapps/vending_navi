import 'package:flutter/material.dart';

import '../models/vending_machine.dart';
import 'checkin_screen.dart';

class MachineDetailScreen extends StatefulWidget {
  const MachineDetailScreen({
    super.key,
    required this.machine,
  });

  final VendingMachine machine;

  @override
  State<MachineDetailScreen> createState() => _MachineDetailScreenState();
}

class _MachineDetailScreenState extends State<MachineDetailScreen> {
  late VendingMachine _machine;

  @override
  void initState() {
    super.initState();
    _machine = widget.machine;
  }

  Future<void> _openCheckin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CheckinScreen(machine: _machine),
      ),
    );

    // 🔥 更新があった場合
    if (result == true) {
      // 今は簡易的に画面を閉じて一覧更新させる
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  List<String> get _products {
    final result = <String>[];
    final used = <String>{};

    for (final slot in _machine.drinkSlots) {
      final name = (slot['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final key = name.toLowerCase();
      if (used.contains(key)) continue;

      used.add(key);
      result.add(name);
    }

    return result;
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
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
              children: [
                Text(
                  _machine.name,
                  style: const TextStyle(
                    fontFamily: 'Noto Sans JP',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                if ((_machine.address ?? '').trim().isNotEmpty)
                  Text(
                    _machine.address!,
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

  Widget _buildDrinkList() {
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
        children: [
          const Text(
            'ラインナップ',
            style: TextStyle(
              fontFamily: 'Noto Sans JP',
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (products.isEmpty)
            const Text(
              'ドリンク情報がありません',
              style: TextStyle(
                fontFamily: 'Noto Sans JP',
                fontSize: 13,
                color: Color(0xFF60707A),
              ),
            )
          else
            ...products.map((drink) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_drink_rounded, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        drink,
                        style: const TextStyle(
                          fontFamily: 'Noto Sans JP',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCheckinButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _openCheckin,
        icon: const Icon(Icons.check_circle_rounded),
        label: const Text('チェックインする'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自販機詳細'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildDrinkList(),
          const SizedBox(height: 16),
          _buildCheckinButton(),
        ],
      ),
    );
  }
}