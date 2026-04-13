import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/vending_machine.dart';
import '../utils/drink_tag_util.dart';
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
  bool _isSavingProducts = false;

  static const Map<String, List<String>> _productPresetsByManufacturer =
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
    '不明': <String>[],
  };

  @override
  void initState() {
    super.initState();
    _machine = widget.machine;
  }

  List<Map<String, dynamic>> get _products {
    final result = <Map<String, dynamic>>[];
    final used = <String>{};

    for (final product in _machine.products) {
      final name = (product['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final key = DrinkTagUtil.normalize(name);
      if (used.contains(key)) continue;

      used.add(key);
      result.add(<String, dynamic>{
        'name': name,
        'tags': List<String>.from(product['tags'] ?? const <String>[]),
      });
    }

    return result;
  }

  List<String> get _presetProducts {
    return _productPresetsByManufacturer[_machine.manufacturer] ??
        const <String>[];
  }

  Future<void> _openCheckin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CheckinScreen(machine: _machine),
      ),
    );

    if (result == true) {
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openEditProducts() async {
    final customController = TextEditingController();
    final tempProducts = _products
        .map((e) => <String, dynamic>{
      'name': (e['name'] ?? '').toString(),
      'tags': List<String>.from(e['tags'] ?? const <String>[]),
    })
        .toList();

    bool hasProduct(String name) {
      return tempProducts.any(
            (e) =>
        DrinkTagUtil.normalize((e['name'] ?? '').toString()) ==
            DrinkTagUtil.normalize(name),
      );
    }

    void addProduct(StateSetter setSheetState, String name) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return;
      if (hasProduct(trimmed)) return;

      setSheetState(() {
        tempProducts.add({
          'name': trimmed,
          'tags': DrinkTagUtil.guessTags(trimmed),
        });
      });
    }

    void removeProduct(StateSetter setSheetState, String name) {
      setSheetState(() {
        tempProducts.removeWhere(
              (e) =>
          DrinkTagUtil.normalize((e['name'] ?? '').toString()) ==
              DrinkTagUtil.normalize(name),
        );
      });
    }

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 120),
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ドリンク編集',
                      style: TextStyle(
                        fontFamily: 'Noto Sans JP',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'メーカー: ${_machine.manufacturer}',
                      style: const TextStyle(
                        fontFamily: 'Noto Sans JP',
                        fontSize: 13,
                        color: Color(0xFF60707A),
                      ),
                    ),
                    if (_presetProducts.isNotEmpty) ...[
                      const SizedBox(height: 14),
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
                        children: _presetProducts.map((product) {
                          final selected = hasProduct(product);
                          return FilterChip(
                            label: Text(product),
                            selected: selected,
                            onSelected: (_) {
                              if (selected) {
                                removeProduct(setSheetState, product);
                              } else {
                                addProduct(setSheetState, product);
                              }
                            },
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
                            controller: customController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (value) {
                              addProduct(setSheetState, value);
                              customController.clear();
                            },
                            decoration: InputDecoration(
                              labelText: '例: 綾鷹',
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
                            onPressed: () {
                              addProduct(
                                setSheetState,
                                customController.text,
                              );
                              customController.clear();
                            },
                            child: const Text('追加'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (tempProducts.isEmpty)
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
                        child: const Text(
                          'まだドリンクは登録されていません',
                          style: TextStyle(
                            fontFamily: 'Noto Sans JP',
                            fontSize: 13,
                            color: Color(0xFF60707A),
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: tempProducts.map((product) {
                              final name =
                              (product['name'] ?? '').toString().trim();
                              final tags = List<String>.from(
                                product['tags'] ?? const <String>[],
                              );

                              return InputChip(
                                label: Text(
                                  tags.isEmpty
                                      ? name
                                      : '$name (${tags.join(" / ")})',
                                ),
                                onDeleted: () {
                                  removeProduct(setSheetState, name);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('保存する'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('キャンセル'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    customController.dispose();

    if (shouldSave != true) return;
    await _saveProducts(tempProducts);
  }

  Future<void> _saveProducts(List<Map<String, dynamic>> products) async {
    if (_isSavingProducts) return;

    setState(() {
      _isSavingProducts = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('vending_machines')
          .doc(_machine.id)
          .update({
        'products': products,
        'drinkSlots': products,
        'updatedAt': Timestamp.now(),
      });

      if (!mounted) return;

      setState(() {
        _machine = _machine.copyWith(
          products: products,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ドリンク情報を保存しました'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存に失敗しました: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProducts = false;
        });
      }
    }
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
                Text(
                  'メーカー: ${_machine.manufacturer}',
                  style: const TextStyle(
                    fontFamily: 'Noto Sans JP',
                    fontSize: 13,
                    color: Color(0xFF60707A),
                  ),
                ),
                if ((_machine.locationName ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _machine.locationName!,
                    style: const TextStyle(
                      fontFamily: 'Noto Sans JP',
                      fontSize: 13,
                      color: Color(0xFF60707A),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection() {
    final hasAddress = (_machine.address ?? '').trim().isNotEmpty;
    final hasNote = (_machine.note ?? '').trim().isNotEmpty;

    if (!hasAddress && !hasNote) {
      return const SizedBox.shrink();
    }

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
            '場所メモ',
            style: TextStyle(
              fontFamily: 'Noto Sans JP',
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (hasAddress) ...[
            const SizedBox(height: 10),
            const Text(
              '住所・メモ',
              style: TextStyle(
                fontFamily: 'Noto Sans JP',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF60707A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _machine.address!,
              style: const TextStyle(
                fontFamily: 'Noto Sans JP',
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
          if (hasNote) ...[
            const SizedBox(height: 10),
            const Text(
              '備考',
              style: TextStyle(
                fontFamily: 'Noto Sans JP',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF60707A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _machine.note!,
              style: const TextStyle(
                fontFamily: 'Noto Sans JP',
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductList() {
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
          Row(
            children: [
              const Text(
                'ラインナップ',
                style: TextStyle(
                  fontFamily: 'Noto Sans JP',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _isSavingProducts ? null : _openEditProducts,
                child: const Text('編集'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (products.isEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isSavingProducts ? null : _openEditProducts,
                child: const Text('ドリンクを登録する'),
              ),
            )
          else
            ...products.map((product) {
              final name = (product['name'] ?? '').toString().trim();
              final tags =
              List<String>.from(product['tags'] ?? const <String>[]);

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_drink_rounded, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontFamily: 'Noto Sans JP',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F6F8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontFamily: 'Noto Sans JP',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF60707A),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
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
    final hasNoteBlock = ((_machine.address ?? '').trim().isNotEmpty) ||
        ((_machine.note ?? '').trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('自販機詳細'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildNoteSection(),
          if (hasNoteBlock) const SizedBox(height: 12),
          _buildProductList(),
          const SizedBox(height: 16),
          _buildCheckinButton(),
        ],
      ),
    );
  }
}