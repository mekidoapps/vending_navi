import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/distance_util.dart';
import '../utils/drink_tag_util.dart';

class MachineCreateScreen extends StatefulWidget {
  const MachineCreateScreen({super.key});

  @override
  State<MachineCreateScreen> createState() => _MachineCreateScreenState();
}

class _MachineCreateScreenState extends State<MachineCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _productInputController = TextEditingController();

  bool _isSaving = false;
  bool _cashlessSupported = false;
  String? _selectedManufacturer;

  final List<String> _selectedTags = <String>[];
  final List<String> _products = <String>[];

  static const List<String> _availableTags = <String>[
    '電子決済OK',
    '現金のみ',
    'ゴミ箱あり',
    '屋内',
    '屋外',
    '駅近',
    '24時間',
  ];

  static const List<String> _manufacturerOptions = <String>[
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

  static const Map<String, List<String>> _drinkPresetsByManufacturer =
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
      'サントリー天然水',
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
      'ワンダ 金の微糖',
      '三ツ矢サイダー',
      '十六茶',
      'カルピスウォーター',
    ],
    'ダイドー': <String>[
      'ダイドーブレンド',
      'デミタスコーヒー',
      'miu',
      '葉の茶',
    ],
    '大塚製薬': <String>[
      'ポカリスエット',
      'ポカリスエット イオンウォーター',
      'オロナミンC',
      'MATCH',
      'エネルゲン',
      'ボディメンテ',
    ],
    'AQUO': <String>[
      '天然水',
      'お〜いお茶',
      '綾鷹',
      'BOSS ブラック',
      'ジョージア ブラック',
      'いろはす',
    ],
    'その他': <String>[],
  };

  List<String> get _presetDrinks {
    if (_selectedManufacturer == null) return const <String>[];
    return _drinkPresetsByManufacturer[_selectedManufacturer] ??
        const <String>[];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationNameController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _imageUrlController.dispose();
    _productInputController.dispose();
    super.dispose();
  }

  Future<void> _fillCurrentLocation() async {
    final position = await DistanceUtil.getCurrentPositionSafe();
    if (!mounted || position == null) return;

    setState(() {
      _latitudeController.text = position.latitude.toStringAsFixed(7);
      _longitudeController.text = position.longitude.toStringAsFixed(7);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('現在地を入力しました'),
      ),
    );
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _togglePresetDrink(String drink) {
    final normalized = DrinkTagUtil.normalize(drink);
    final exists =
    _products.any((e) => DrinkTagUtil.normalize(e) == normalized);

    setState(() {
      if (exists) {
        _products.removeWhere((e) => DrinkTagUtil.normalize(e) == normalized);
      } else {
        _products.add(drink);
      }
    });
  }

  void _addProduct() {
    final value = _productInputController.text.trim();
    if (value.isEmpty) return;

    final normalized = DrinkTagUtil.normalize(value);
    final exists =
    _products.any((e) => DrinkTagUtil.normalize(e) == normalized);
    if (exists) {
      _productInputController.clear();
      return;
    }

    setState(() {
      _products.add(value);
      _productInputController.clear();
    });
  }

  void _removeProduct(String product) {
    setState(() {
      _products.removeWhere(
            (e) => DrinkTagUtil.normalize(e) == DrinkTagUtil.normalize(product),
      );
    });
  }

  String _buildAutoName() {
    final typedName = _nameController.text.trim();
    if (typedName.isNotEmpty) return typedName;

    final locationName = _locationNameController.text.trim();
    final manufacturer = (_selectedManufacturer ?? '').trim();

    if (locationName.isNotEmpty && manufacturer.isNotEmpty) {
      return '$locationName の $manufacturer 自販機';
    }
    if (locationName.isNotEmpty) {
      return '$locationName の自販機';
    }
    if (manufacturer.isNotEmpty) {
      return '$manufacturer 自販機';
    }
    return '自販機';
  }

  List<Map<String, dynamic>> _buildProductsPayload() {
    final result = <Map<String, dynamic>>[];

    for (final product in _products) {
      final trimmed = product.trim();
      if (trimmed.isEmpty) continue;

      result.add({
        'name': trimmed,
        'tags': DrinkTagUtil.guessTags(trimmed),
      });
    }

    return result;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final lat = double.tryParse(_latitudeController.text.trim());
    final lng = double.tryParse(_longitudeController.text.trim());

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('緯度・経度を正しく入力してください'),
        ),
      );
      return;
    }

    if ((_selectedManufacturer ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メーカーを選択してください'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = Timestamp.now();
      final productsPayload = _buildProductsPayload();

      final createdDoc =
      await FirebaseFirestore.instance.collection('vending_machines').add({
        'name': _buildAutoName(),
        'locationName': _locationNameController.text.trim(),
        'address': _addressController.text.trim(),
        'note': _noteController.text.trim(),
        'lat': lat,
        'lng': lng,
        'latitude': lat,
        'longitude': lng,
        'imageUrl': _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        'tags': _selectedTags,
        'cashlessSupported': _cashlessSupported,
        'manufacturer': _selectedManufacturer,
        'products': productsPayload,
        'drinkSlots': productsPayload,
        'createdAt': now,
        'updatedAt': now,
        'lastCheckedAt': now,
        'checkinCount': 0,
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '・ドリンク未登録でもOKです',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '今このままドリンクを登録することもできます。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
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

      Navigator.of(context).pop({
        'created': true,
        'openDetail': goToEdit == true,
        'machineId': createdDoc.id,
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('登録に失敗しました: $e'),
        ),
      );
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  InputDecoration _decoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildManufacturerSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE3E7EB),
        ),
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
            'メーカー',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '先にメーカーを選ぶと、候補ドリンクをすぐ追加できます。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _manufacturerOptions.map((manufacturer) {
              final selected = _selectedManufacturer == manufacturer;
              return ChoiceChip(
                label: Text(manufacturer),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedManufacturer = manufacturer;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetDrinkSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE3E7EB),
        ),
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
            '飲み物',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'あとで追加できます。今は候補からざっくり選んでもOKです。',
            style: theme.textTheme.bodySmall,
          ),
          if (_presetDrinks.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              '候補から追加',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetDrinks.map((drink) {
                final selected = _products.any(
                      (e) =>
                  DrinkTagUtil.normalize(e) ==
                      DrinkTagUtil.normalize(drink),
                );
                return FilterChip(
                  label: Text(drink),
                  selected: selected,
                  onSelected: (_) => _togglePresetDrink(drink),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _productInputController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addProduct(),
                  decoration: _decoration(context, '例: お〜いお茶'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _addProduct,
                  child: const Text('追加'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_products.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE3E7EB),
                ),
              ),
              child: Text(
                'まだ飲み物は追加されていません',
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _products.map((product) {
                final tags = DrinkTagUtil.guessTags(product);
                return InputChip(
                  label: Text(
                    tags.isEmpty ? product : '$product (${tags.join(" / ")})',
                  ),
                  onDeleted: () => _removeProduct(product),
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('自販機を登録'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7EF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFFD8B6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'サクッと登録できます',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'まずはメーカーだけでもOKです。ドリンクはあとで編集できます。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '登録名プレビュー: ${_buildAutoName()}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildManufacturerSection(theme),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE3E7EB),
                  ),
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
                      '基本情報',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(context, '自販機名（空でもOK）'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationNameController,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(context, '場所名'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(context, '住所・メモ'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(context, '備考（例: B1 エレベーター横）'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _imageUrlController,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(context, '画像URL（任意）'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE3E7EB),
                  ),
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
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitudeController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: _decoration(context, '緯度'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '緯度を入力してください';
                              }
                              if (double.tryParse(value.trim()) == null) {
                                return '数値で入力してください';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _longitudeController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: _decoration(context, '経度'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '経度を入力してください';
                              }
                              if (double.tryParse(value.trim()) == null) {
                                return '数値で入力してください';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _fillCurrentLocation,
                        icon: const Icon(Icons.my_location_rounded),
                        label: const Text('現在地を入力する'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE3E7EB),
                  ),
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
                      '支払い・タグ',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('電子決済対応'),
                      subtitle: const Text('交通系IC・QR決済など'),
                      value: _cashlessSupported,
                      onChanged: (value) {
                        setState(() {
                          _cashlessSupported = value;
                          if (value) {
                            _selectedTags.remove('現金のみ');
                            if (!_selectedTags.contains('電子決済OK')) {
                              _selectedTags.add('電子決済OK');
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableTags.map((tag) {
                        final selected = _selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: selected,
                          onSelected: (_) => _toggleTag(tag),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildPresetDrinkSection(theme),
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
      ),
    );
  }
}