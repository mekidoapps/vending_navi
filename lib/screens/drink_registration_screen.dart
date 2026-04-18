import 'package:flutter/material.dart';

import 'drink_registration_screen.dart';
import '../models/drink_slot_data.dart';

class RegisterVendingMachineScreen extends StatefulWidget {
  const RegisterVendingMachineScreen({super.key});

  @override
  State<RegisterVendingMachineScreen> createState() =>
      _RegisterVendingMachineScreenState();
}

class _RegisterVendingMachineScreenState
    extends State<RegisterVendingMachineScreen> {
  String? selectedManufacturer;

  List<DrinkSlotData> drinkSlots =
  List<DrinkSlotData>.generate(12, (int i) => DrinkSlotData(index: i));

  final List<String> manufacturers = <String>[
    'コカコーラ',
    'サントリー',
    '大塚製薬',
    '伊藤園',
    'キリン',
    'アサヒ',
    'その他',
  ];

  Future<void> _openDrinkRegistration() async {
    final List<DrinkSlotData>? result =
    await Navigator.of(context).push<List<DrinkSlotData>>(
      MaterialPageRoute(
        builder: (_) => DrinkRegistrationScreen(
          initialManufacturer: selectedManufacturer,
          initialSlots: drinkSlots,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        drinkSlots = result;
      });
    }
  }

  int get registeredCount =>
      drinkSlots.where((e) => e.name != null && e.name!.isNotEmpty).length;

  List<String> get registeredDrinkNames => drinkSlots
      .where((e) => e.name != null && e.name!.isNotEmpty)
      .map((e) => e.name!)
      .toList();

  void _saveMachine({required bool skippedDrinkRegistration}) {
    debugPrint('メーカー: $selectedManufacturer');
    debugPrint('ドリンク登録スキップ: $skippedDrinkRegistration');
    debugPrint('ドリンク: ${registeredDrinkNames.join(', ')}');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          skippedDrinkRegistration
              ? 'ドリンク未登録で保存しました'
              : '自販機情報を保存しました',
        ),
      ),
    );

    // TODO:
    // Firestore保存処理
    // Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDrinks = registeredCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('自販機登録'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const Text(
              'メーカー',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: manufacturers.map((String maker) {
                final bool selected = maker == selectedManufacturer;
                return ChoiceChip(
                  label: Text(maker),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      selectedManufacturer = maker;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF8FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD9E7F2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'ドリンク登録',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '見かけたものだけでOKです。あとで追加もできます。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF60707A),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '登録済み: $registeredCount / 12',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF60707A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasDrinks) ...<Widget>[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: registeredDrinkNames.take(6).map((String name) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFD9E7F2),
                            ),
                          ),
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334148),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (registeredDrinkNames.length > 6) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'ほか ${registeredDrinkNames.length - 6} 件',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF60707A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _openDrinkRegistration,
                      child: Text(hasDrinks ? 'ドリンクを編集する' : 'ドリンクを登録する'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        _saveMachine(skippedDrinkRegistration: !hasDrinks);
                      },
                      child: const Text('あとで登録する'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                _saveMachine(skippedDrinkRegistration: !hasDrinks);
              },
              child: Text(
                hasDrinks ? 'この内容で登録' : 'ドリンク未登録で登録',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'ドリンク情報は後から追加・編集できます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF60707A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}