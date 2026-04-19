import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/drink_slot_data.dart';
import '../services/vending_machine_service.dart';
import 'drink_registration_screen.dart';

class RegisterVendingMachineScreen extends StatefulWidget {
  const RegisterVendingMachineScreen({
    super.key,
    this.machineId,
  });

  final String? machineId;

  @override
  State<RegisterVendingMachineScreen> createState() =>
      _RegisterVendingMachineScreenState();
}

class _RegisterVendingMachineScreenState
    extends State<RegisterVendingMachineScreen> {
  final VendingMachineService _service = VendingMachineService();

  String? selectedManufacturer;
  bool isSaving = false;
  bool isLoadingMachine = false;

  List<DrinkSlotData> drinkSlots =
  List<DrinkSlotData>.generate(12, (_) => const DrinkSlotData());

  final List<String> manufacturers = <String>[
    'コカコーラ',
    'サントリー',
    '大塚製薬',
    '伊藤園',
    'キリン',
    'アサヒ',
    'その他',
  ];

  bool get isEditMode {
    final String? id = widget.machineId;
    return id != null && id.trim().isNotEmpty;
  }

  int get registeredCount =>
      drinkSlots.where((e) => (e.name ?? '').trim().isNotEmpty).length;

  List<String> get registeredDrinkNames => drinkSlots
      .map((e) => (e.name ?? '').trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  bool get hasDrinks => registeredCount > 0;

  bool get hasManufacturer =>
      selectedManufacturer != null && selectedManufacturer!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _loadExistingMachine();
    }
  }

  Future<void> _loadExistingMachine() async {
    if (!isEditMode) return;

    setState(() {
      isLoadingMachine = true;
    });

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('vending_machines')
          .doc(widget.machineId)
          .get();

      if (!mounted) return;
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('編集対象の自販機が見つかりませんでした')),
        );
        return;
      }

      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
      final String manufacturer =
      (data['manufacturer'] ?? '').toString().trim();
      final List<DrinkSlotData> loadedSlots = _slotsFromMachineData(data);

      setState(() {
        selectedManufacturer = manufacturer.isEmpty ? null : manufacturer;
        drinkSlots = loadedSlots;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('既存データの読み込みに失敗しました: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isLoadingMachine = false;
      });
    }
  }

  List<DrinkSlotData> _slotsFromMachineData(Map<String, dynamic> data) {
    final List<DrinkSlotData> base =
    List<DrinkSlotData>.generate(12, (_) => const DrinkSlotData());

    final dynamic rawSlots = data['drinkSlots'];
    if (rawSlots is List) {
      for (int i = 0; i < rawSlots.length && i < base.length; i++) {
        final dynamic item = rawSlots[i];
        if (item is Map) {
          base[i] = DrinkSlotData.fromMap(Map<String, dynamic>.from(item));
        }
      }
      return base;
    }

    final dynamic rawProducts = data['products'];
    if (rawProducts is List) {
      for (int i = 0; i < rawProducts.length && i < base.length; i++) {
        final dynamic item = rawProducts[i];
        if (item is Map) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(item);
          base[i] = DrinkSlotData(
            name: _normalizedNullableString(map['name']),
            tags: _stringList(map['tags']),
            isSoldOut: map['isSoldOut'] == true,
          );
        }
      }
      return base;
    }

    final dynamic rawDrinks = data['drinks'];
    if (rawDrinks is List) {
      for (int i = 0; i < rawDrinks.length && i < base.length; i++) {
        final String name = rawDrinks[i].toString().trim();
        if (name.isNotEmpty) {
          base[i] = DrinkSlotData(name: name);
        }
      }
    }

    return base;
  }

  String? _normalizedNullableString(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  List<String> _stringList(dynamic source) {
    if (source is! List) return const <String>[];
    return source
        .map((dynamic e) => e.toString().trim())
        .where((String e) => e.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _openDrinkRegistration() async {
    final List<DrinkSlotData>? result =
    await Navigator.of(context).push<List<DrinkSlotData>>(
      MaterialPageRoute(
        builder: (_) => DrinkRegistrationScreen(
          initialSlots: drinkSlots,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        drinkSlots = List<DrinkSlotData>.generate(
          12,
              (int i) => i < result.length ? result[i] : const DrinkSlotData(),
        );
      });
    }
  }

  Future<void> _saveMachine({required bool skippedDrinkRegistration}) async {
    if (isSaving || isLoadingMachine) return;

    setState(() {
      isSaving = true;
    });

    try {
      if (isEditMode) {
        await FirebaseFirestore.instance
            .collection('vending_machines')
            .doc(widget.machineId)
            .update(<String, dynamic>{
          'manufacturer': selectedManufacturer ?? 'その他',
          'drinkSlots': drinkSlots.map((e) => e.toMap()).toList(),
          'drinks': registeredDrinkNames,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              skippedDrinkRegistration
                  ? 'ドリンク未登録のまま更新しました'
                  : 'ドリンク情報を更新しました',
            ),
          ),
        );

        Navigator.pop(
          context,
          <String, dynamic>{
            'updated': true,
            'machineId': widget.machineId,
          },
        );
        return;
      }

      const double latitude = 35.681236;
      const double longitude = 139.767125;

      final String machineId = await _service.createMachine(
        latitude: latitude,
        longitude: longitude,
        manufacturer: selectedManufacturer ?? 'その他',
        memo: null,
        placeNote: null,
        createdBy: null,
        drinkSlots: drinkSlots,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            skippedDrinkRegistration
                ? 'ドリンク未登録で保存しました'
                : '自販機情報を保存しました',
          ),
        ),
      );

      Navigator.pop(
        context,
        <String, dynamic>{
          'created': true,
          'machineId': machineId,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'ドリンク登録 / 編集' : '自販機登録'),
      ),
      body: SafeArea(
        child: isLoadingMachine
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: manufacturers.map((String maker) {
                return ChoiceChip(
                  label: Text(maker),
                  selected: selectedManufacturer == maker,
                  onSelected: isSaving
                      ? null
                      : (_) {
                    setState(() {
                      selectedManufacturer = maker;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              hasManufacturer
                  ? '選択中メーカー: $selectedManufacturer'
                  : 'メーカー未選択でも登録できます',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: isSaving ? null : _openDrinkRegistration,
              child: Text(hasDrinks ? 'ドリンクを編集する' : 'ドリンクを登録する'),
            ),
            const SizedBox(height: 12),
            Text('登録済み: $registeredCount / 12'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: registeredDrinkNames
                  .map(
                    (String name) => Chip(label: Text(name)),
              )
                  .toList(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () => _saveMachine(
                skippedDrinkRegistration: !hasDrinks,
              ),
              child: isSaving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Text(
                isEditMode
                    ? (hasDrinks ? 'この内容で更新' : 'ドリンク未登録で更新')
                    : (hasDrinks ? 'この内容で登録' : 'ドリンク未登録で登録'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
