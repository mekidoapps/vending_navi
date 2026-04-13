import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterVendingMachineScreen extends StatefulWidget {
  const RegisterVendingMachineScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.address,
    this.locationName,
  });

  final double latitude;
  final double longitude;
  final String? address;
  final String? locationName;

  @override
  State<RegisterVendingMachineScreen> createState() =>
      _RegisterVendingMachineScreenState();
}

class _RegisterVendingMachineScreenState
    extends State<RegisterVendingMachineScreen> {
  static const Map<String, List<String>> _makerPresets =
  <String, List<String>>{
    'コカ・コーラ': <String>[
      'コカ・コーラ',
      'コカ・コーラゼロ',
      '綾鷹',
      '爽健美茶',
      'いろはす',
      'ジョージア ブラック',
      'ジョージア カフェオレ',
    ],
    'サントリー': <String>[
      'BOSS ブラック',
      'BOSS カフェオレ',
      '伊右衛門',
      'ペプシ',
      'なっちゃん',
      '天然水',
    ],
    '伊藤園': <String>[
      'お〜いお茶',
      '健康ミネラルむぎ茶',
      '充実野菜',
      'TULLY\'S COFFEE',
    ],
    'キリン': <String>[
      '午後の紅茶',
      '生茶',
      'キリンレモン',
      'FIRE ブラック',
    ],
    'アサヒ': <String>[
      'ワンダ モーニングショット',
      '三ツ矢サイダー',
      '十六茶',
      'カルピス',
    ],
    'ダイドー': <String>[
      'ダイドーブレンド',
      'デミタスコーヒー',
      'miu',
    ],
    'その他': <String>[],
  };

  static const List<String> _makerOptions = <String>[
    'コカ・コーラ',
    'サントリー',
    '伊藤園',
    'キリン',
    'アサヒ',
    'ダイドー',
    'その他',
  ];

  final TextEditingController _customDrinkController = TextEditingController();

  String? _selectedMaker;
  bool _isSaving = false;
  final List<String> _selectedDrinks = <String>[];

  @override
  void dispose() {
    _customDrinkController.dispose();
    super.dispose();
  }

  String _normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('　', '')
        .replaceAll(' ', '')
        .replaceAll('〜', 'ー')
        .replaceAll('～', 'ー')
        .replaceAll('-', 'ー');
  }

  List<String> _presetDrinks() {
    if (_selectedMaker == null) return const <String>[];
    return _makerPresets[_selectedMaker] ?? const <String>[];
  }

  void _toggleDrink(String drink) {
    setState(() {
      final exists =
      _selectedDrinks.any((e) => _normalize(e) == _normalize(drink));
      if (exists) {
        _selectedDrinks.removeWhere(
              (e) => _normalize(e) == _normalize(drink),
        );
      } else {
        _selectedDrinks.add(drink);
      }
    });
  }

  void _addCustomDrink() {
    final value = _customDrinkController.text.trim();
    if (value.isEmpty) return;

    final exists = _selectedDrinks.any(
          (e) => _normalize(e) == _normalize(value),
    );
    if (exists) {
      _customDrinkController.clear();
      return;
    }

    setState(() {
      _selectedDrinks.add(value);
      _customDrinkController.clear();
    });
  }

  void _removeDrink(String drink) {
    setState(() {
      _selectedDrinks.removeWhere(
            (e) => _normalize(e) == _normalize(drink),
      );
    });
  }

  String _buildAutoName() {
    final location = (widget.locationName ?? '').trim();
    final maker = (_selectedMaker ?? '').trim();

    if (location.isNotEmpty && maker.isNotEmpty) {
      return '$location の $maker 自販機';
    }
    if (location.isNotEmpty) {
      return '$location の自販機';
    }
    if (maker.isNotEmpty) {
      return '$maker 自販機';
    }
    return '自販機';
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登録にはログインが必要です')),
      );
      return;
    }

    if (_selectedMaker == null || _selectedMaker!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メーカーを選択してください')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = Timestamp.now();

      final drinkSlots = _selectedDrinks.map((product) {
        return <String, dynamic>{
          'name': product,
          'price': null,
          'isAvailable': true,
        };
      }).toList();

      final createdDoc =
      await FirebaseFirestore.instance.collection('vending_machines').add({
        'name': _buildAutoName(),
        'locationName': (widget.locationName ?? '').trim(),
        'address': (widget.address ?? '').trim(),
        'latitude': widget.latitude,
        'longitude': widget.longitude,
        'imageUrl': null,
        'tags': <String>[],
        'cashlessSupported': false,
        'manufacturer': _selectedMaker,
        'drinkSlots': drinkSlots,
        'status': 'available',
        'createdAt': now,
        'updatedAt': now,
        'lastCheckedAt': now,
        'createdBy': user.uid,
      });

      if (!mounted) return;

      final goToEdit = await showModalBottomSheet<bool>(
        context: context,
        isDismissible: true,
        enableDrag: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '登録しました',
                    style: TextStyle(
                      fontFamily: 'Noto Sans JP',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F8FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '・あとで編集できます',
                          style: TextStyle(
                            fontFamily: 'Noto Sans JP',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '・ドリンク未登録でもOKです',
                          style: TextStyle(
                            fontFamily: 'Noto Sans JP',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '今このままドリンクを調整することもできます。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Noto Sans JP',
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('今ドリンクを登録する'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('あとでやる'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (!mounted) return;

      Navigator.of(context).pop(<String, dynamic>{
        'created': true,
        'openDetail': goToEdit == true,
        'machineId': createdDoc.id,
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登録に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildMakerSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE3E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'メーカー',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'まずはメーカーだけで登録できます。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _makerOptions.map((maker) {
              final selected = _selectedMaker == maker;
              return ChoiceChip(
                label: Text(maker),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedMaker = maker;
                    _selectedDrinks.clear();
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE3E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '位置情報',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: '緯度',
            value: widget.latitude.toStringAsFixed(7),
          ),
          _InfoRow(
            label: '経度',
            value: widget.longitude.toStringAsFixed(7),
          ),
          if ((widget.locationName ?? '').trim().isNotEmpty)
            _InfoRow(
              label: '場所名',
              value: widget.locationName!.trim(),
            ),
          if ((widget.address ?? '').trim().isNotEmpty)
            _InfoRow(
              label: '住所',
              value: widget.address!.trim(),
            ),
        ],
      ),
    );
  }

  Widget _buildPresetSection(ThemeData theme) {
    final presets = _presetDrinks();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE3E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ドリンク',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'あとで追加できます。今ここで選んでもOKです。',
            style: theme.textTheme.bodySmall,
          ),
          if (presets.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              '候補から追加',
              style: TextStyle(
                fontFamily: 'Noto Sans JP',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((drink) {
                final selected = _selectedDrinks.any(
                      (e) => _normalize(e) == _normalize(drink),
                );

                return FilterChip(
                  label: Text(drink),
                  selected: selected,
                  onSelected: (_) => _toggleDrink(drink),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            '自由入力で追加',
            style: TextStyle(
              fontFamily: 'Noto Sans JP',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customDrinkController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addCustomDrink(),
                  decoration: InputDecoration(
                    labelText: '例: お〜いお茶',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _addCustomDrink,
                  child: const Text('追加'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedDrinks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE3E7EB)),
              ),
              child: const Text(
                'まだドリンクは追加されていません',
                style: TextStyle(
                  fontFamily: 'Noto Sans JP',
                  fontSize: 13,
                  color: Color(0xFF60707A),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedDrinks.map((drink) {
                return InputChip(
                  label: Text(drink),
                  onDeleted: () => _removeDrink(drink),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewName = _buildAutoName();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('自販機を登録'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7EF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFD8B6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'サクッと登録できます',
                    style: TextStyle(
                      fontFamily: 'Noto Sans JP',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'まずはメーカーだけでもOKです。ドリンクはあとから追加できます。',
                    style: TextStyle(
                      fontFamily: 'Noto Sans JP',
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '登録名プレビュー: $previewName',
                    style: const TextStyle(
                      fontFamily: 'Noto Sans JP',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildMakerSection(theme),
            const SizedBox(height: 14),
            _buildLocationSection(theme),
            const SizedBox(height: 14),
            _buildPresetSection(theme),
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? '登録中...' : '登録する'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: _isSaving
                    ? null
                    : () {
                  Navigator.of(context).pop();
                },
                child: const Text('キャンセル'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Noto Sans JP',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF60707A),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Noto Sans JP',
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}