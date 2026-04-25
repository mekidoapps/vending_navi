import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/drink_slot_data.dart';
import '../services/user_progress_service.dart';
import '../services/vending_machine_service.dart';
import '../widgets/title_unlock_overlay.dart';
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
  static const List<String> _manufacturers = <String>[
    'コカ・コーラ',
    'サントリー',
    '伊藤園',
    'キリン',
    'アサヒ',
    'ダイドー',
    '大塚製薬',
    'AQUO',
    'その他',
  ];

  final VendingMachineService _service = VendingMachineService();

  String? _selectedManufacturer;
  bool _isSaving = false;
  bool _isLoadingMachine = false;
  int _initialRegisteredDrinkCount = 0;

  List<DrinkSlotData> _drinkSlots =
  List<DrinkSlotData>.generate(12, (_) => const DrinkSlotData());

  bool get _isEditMode {
    final String? id = widget.machineId;
    return id != null && id.trim().isNotEmpty;
  }

  int get _registeredCount =>
      _drinkSlots.where((DrinkSlotData e) => e.hasName).length;

  List<String> get _registeredDrinkNames => _drinkSlots
      .map((DrinkSlotData e) => (e.name ?? '').trim())
      .where((String e) => e.isNotEmpty)
      .toList(growable: false);

  bool get _hasDrinks => _registeredCount > 0;

  bool get _hasManufacturer =>
      _selectedManufacturer != null && _selectedManufacturer!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadExistingMachine();
    }
  }

  String? _normalizeManufacturer(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return null;

    switch (text) {
      case 'コカコーラ':
      case 'Coca-Cola':
      case 'coca-cola':
        return 'コカ・コーラ';
      default:
        return text;
    }
  }

  Future<void> _loadExistingMachine() async {
    if (!_isEditMode) return;

    setState(() {
      _isLoadingMachine = true;
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
        setState(() {
          _isLoadingMachine = false;
        });
        return;
      }

      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
      final List<DrinkSlotData> loadedSlots = _slotsFromMachineData(data);

      setState(() {
        _selectedManufacturer =
            _normalizeManufacturer(data['manufacturer']?.toString());
        _drinkSlots = loadedSlots;
        _initialRegisteredDrinkCount =
            loadedSlots.where((DrinkSlotData e) => e.hasName).length;
        _isLoadingMachine = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMachine = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('既存データの読み込みに失敗しました: $e')),
      );
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
        } else {
          final String text = item.toString().trim();
          if (text.isNotEmpty) {
            base[i] = DrinkSlotData(name: text);
          }
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
      MaterialPageRoute<List<DrinkSlotData>>(
        builder: (_) => DrinkRegistrationScreen(
          manufacturer: _selectedManufacturer,
          initialSlots: _drinkSlots,
        ),
      ),
    );

    if (!mounted || result == null) return;

    final List<DrinkSlotData> normalized = List<DrinkSlotData>.generate(
      12,
          (int i) => i < result.length ? result[i] : const DrinkSlotData(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _drinkSlots = normalized;
      });
    });
  }

  Future<ProgressApplyResult> _applyProgressAfterCreate() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return ProgressApplyResult.empty();
    }

    final String displayName =
    (user.displayName ?? '').trim().isNotEmpty ? user.displayName!.trim() : 'ユーザー';

    return UserProgressService.instance.applyMachineRegisterProgress(
      uid: user.uid,
      displayName: displayName,
      addedDrinkCount: _registeredCount,
    );
  }

  Future<ProgressApplyResult> _applyProgressAfterEdit() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return ProgressApplyResult.empty();
    }

    final int addedDrinkCount = _registeredCount - _initialRegisteredDrinkCount;
    if (addedDrinkCount <= 0) {
      return ProgressApplyResult.empty();
    }

    final String displayName =
    (user.displayName ?? '').trim().isNotEmpty ? user.displayName!.trim() : 'ユーザー';

    return UserProgressService.instance.applyDrinkRegisterProgress(
      uid: user.uid,
      displayName: displayName,
      addedDrinkCount: addedDrinkCount,
    );
  }

  Future<void> _showUnlockedTitlesIfNeeded(ProgressApplyResult result) async {
    if (!mounted || !result.hasUnlockedTitles) return;
    await TitleUnlockOverlay.show(
      context,
      titles: result.earnedTitles,
    );
  }

  Future<void> _saveMachine({required bool skippedDrinkRegistration}) async {
    if (_isSaving || _isLoadingMachine) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEditMode) {
        await FirebaseFirestore.instance
            .collection('vending_machines')
            .doc(widget.machineId)
            .update(<String, dynamic>{
          'manufacturer': _selectedManufacturer ?? 'その他',
          'drinkSlots': _drinkSlots.map((DrinkSlotData e) => e.toMap()).toList(),
          'drinks': _registeredDrinkNames,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final ProgressApplyResult progressResult = await _applyProgressAfterEdit();

        if (!mounted) return;

        await _showUnlockedTitlesIfNeeded(progressResult);

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

        Navigator.of(context).pop(<String, dynamic>{
          'updated': true,
          'machineId': widget.machineId,
          'earnedTitles': progressResult.earnedTitles,
        });
        return;
      }

      const double latitude = 35.681236;
      const double longitude = 139.767125;

      final String machineId = await _service.createMachine(
        latitude: latitude,
        longitude: longitude,
        manufacturer: _selectedManufacturer ?? 'その他',
        memo: null,
        placeNote: null,
        createdBy: null,
        drinkSlots: _drinkSlots,
      );

      final ProgressApplyResult progressResult = await _applyProgressAfterCreate();

      if (!mounted) return;

      await _showUnlockedTitlesIfNeeded(progressResult);

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

      Navigator.of(context).pop(<String, dynamic>{
        'created': true,
        'machineId': machineId,
        'earnedTitles': progressResult.earnedTitles,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      appBar: AppBar(
        title: Text(_isEditMode ? 'ドリンク登録 / 編集' : '自販機登録'),
      ),
      body: SafeArea(
        child: _isLoadingMachine
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE3E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'メーカー',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334148),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _manufacturers.map((String maker) {
                      return ChoiceChip(
                        label: Text(maker),
                        selected: _selectedManufacturer == maker,
                        onSelected: _isSaving
                            ? null
                            : (_) {
                          setState(() {
                            _selectedManufacturer = maker;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _hasManufacturer
                        ? '選択中メーカー: $_selectedManufacturer'
                        : 'メーカー未選択でも登録できます',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF60707A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE3E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'ドリンク登録',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334148),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '見かけたものだけでOKです。あとで追加できます。',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF60707A),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _isSaving ? null : _openDrinkRegistration,
                    child:
                    Text(_hasDrinks ? 'ドリンクを編集する' : 'ドリンクを登録する'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '登録済み: $_registeredCount / 12',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF60707A),
                    ),
                  ),
                  if (_registeredDrinkNames.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _registeredDrinkNames
                          .map((String name) => Chip(label: Text(name)))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving
                  ? null
                  : () => _saveMachine(
                skippedDrinkRegistration: !_hasDrinks,
              ),
              child: _isSaving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Text(
                _isEditMode
                    ? (_hasDrinks ? 'この内容で更新' : 'ドリンク未登録で更新')
                    : (_hasDrinks ? 'この内容で登録' : 'ドリンク未登録で登録'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}