import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/distance_util.dart';

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
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _productInputController = TextEditingController();

  bool _isSaving = false;
  bool _cashlessSupported = false;

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

  @override
  void dispose() {
    _nameController.dispose();
    _locationNameController.dispose();
    _addressController.dispose();
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

  void _addProduct() {
    final value = _productInputController.text.trim();
    if (value.isEmpty) return;

    final normalized = _normalize(value);
    final exists = _products.any((e) => _normalize(e) == normalized);
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
      _products.remove(product);
    });
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

    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('飲み物を1つ以上追加してください'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = Timestamp.now();

      final drinkSlots = _products.map((product) {
        return <String, dynamic>{
          'name': product,
          'price': null,
          'isAvailable': true,
        };
      }).toList();

      await FirebaseFirestore.instance.collection('vending_machines').add({
        'name': _nameController.text.trim(),
        'locationName': _locationNameController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': lat,
        'longitude': lng,
        'imageUrl': _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        'tags': _selectedTags,
        'cashlessSupported': _cashlessSupported,
        'drinkSlots': drinkSlots,
        'status': 'available',
        'createdAt': now,
        'updatedAt': now,
        'lastCheckedAt': now,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('自販機を登録しました'),
        ),
      );

      Navigator.of(context).pop(true);
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
                      decoration: _decoration(context, '自販機名'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '自販機名を入力してください';
                        }
                        return null;
                      },
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
                      '飲み物',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '商品名を追加してください',
                      style: theme.textTheme.bodySmall,
                    ),
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
                          'まだ飲み物が追加されていません',
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _products.map((product) {
                          return InputChip(
                            label: Text(product),
                            onDeleted: () => _removeProduct(product),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
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
                  label: Text(_isSaving ? '登録中...' : 'この内容で登録'),
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