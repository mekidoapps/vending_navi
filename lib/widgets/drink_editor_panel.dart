import 'package:flutter/material.dart';

import '../models/drink_slot.dart';

class DrinkEditorPanel extends StatefulWidget {
  const DrinkEditorPanel({
    super.key,
    required this.mode,
    required this.selectedSlot,
    required this.onSave,
    required this.onDelete,
  });

  final DrinkShelfMode mode;
  final DrinkSlot? selectedSlot;
  final ValueChanged<DrinkSlot> onSave;
  final ValueChanged<DrinkSlot> onDelete;

  @override
  State<DrinkEditorPanel> createState() => _DrinkEditorPanelState();
}

class _DrinkEditorPanelState extends State<DrinkEditorPanel> {
  static const List<String> _manufacturers = <String>[
    'コカ・コーラ',
    'サントリー',
    '伊藤園',
    'アサヒ',
    'キリン',
    'ダイドー',
    'ポッカ',
    'その他',
  ];

  static const List<String> _categories = <String>[
    'お茶',
    'コーヒー',
    '炭酸',
    '水',
    'スポーツ',
    '紅茶',
    'ジュース',
    'エナジー',
    'その他',
  ];

  static const Map<String, List<String>> _drinkCandidates =
  <String, List<String>>{
    'コカ・コーラ|お茶': <String>[
      '綾鷹',
      '綾鷹 濃い緑茶',
      '爽健美茶',
      'からだすこやか茶W',
      'やかんの麦茶',
    ],
    'コカ・コーラ|コーヒー': <String>[
      'ジョージア ブラック',
      'ジョージア 微糖',
      'ジョージア カフェラテ',
      'ジョージア ザ・ラテ',
    ],
    'コカ・コーラ|炭酸': <String>[
      'コカ・コーラ',
      'コカ・コーラ ゼロ',
      'ファンタ グレープ',
      'ファンタ オレンジ',
      'スプライト',
    ],
    'コカ・コーラ|水': <String>[
      'い・ろ・は・す',
    ],
    'サントリー|お茶': <String>[
      '伊右衛門',
      '伊右衛門 濃い味',
      '烏龍茶',
      'GREEN DA・KA・RA やさしい麦茶',
      '胡麻麦茶',
    ],
    'サントリー|コーヒー': <String>[
      'BOSS ブラック',
      'BOSS レインボーマウンテン',
      'クラフトボス ブラック',
      'クラフトボス ラテ',
      'プレミアムボス',
    ],
    'サントリー|炭酸': <String>[
      'ペプシ',
      'デカビタC',
      'C.C.レモン',
      'POPメロンソーダ',
    ],
    '伊藤園|お茶': <String>[
      'お〜いお茶 緑茶',
      'お〜いお茶 濃い茶',
      '健康ミネラルむぎ茶',
      'ほうじ茶',
    ],
    '伊藤園|水': <String>[
      '磨かれて、澄みきった日本の水',
    ],
    'アサヒ|コーヒー': <String>[
      'ワンダ モーニングショット',
      'ワンダ 金の微糖',
      'ワンダ ブラック',
      'ワンダ カフェオレ',
    ],
    'アサヒ|炭酸': <String>[
      '三ツ矢サイダー',
      'ウィルキンソン タンサン',
      'ドデカミン',
    ],
    'アサヒ|水': <String>[
      'おいしい水 天然水',
    ],
    'キリン|お茶': <String>[
      '生茶',
      '生茶 ほうじ煎茶',
      '午後の紅茶 おいしい無糖',
      '午後の紅茶 ミルクティー',
    ],
    'キリン|炭酸': <String>[
      'キリンレモン',
      'メッツ コーラ',
      'メッツ グレープフルーツ',
    ],
    'ダイドー|コーヒー': <String>[
      'ダイドーブレンド',
      'ダイドーブレンド 微糖',
      'ダイドーブレンド ブラック',
    ],
    'ポッカ|コーヒー': <String>[
      'ポッカコーヒー オリジナル',
      'ポッカコーヒー ブラック',
      '加賀棒ほうじ茶ラテ',
    ],
  };

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manufacturerFreeController =
  TextEditingController();
  final TextEditingController _categoryFreeController = TextEditingController();

  String? _selectedManufacturer;
  String? _selectedCategory;
  bool _isSoldOut = false;
  bool _useFreeInput = false;

  bool get _isEditable => widget.mode != DrinkShelfMode.view;

  String get _candidateKey =>
      '${_selectedManufacturer?.trim() ?? ''}|${_selectedCategory?.trim() ?? ''}';

  List<String> get _candidateProducts {
    final list = _drinkCandidates[_candidateKey] ?? <String>[];
    final q = _searchController.text.trim().toLowerCase();

    if (q.isEmpty) return list;

    return list.where((item) => item.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _applySlot(widget.selectedSlot);
  }

  @override
  void didUpdateWidget(covariant DrinkEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedSlot?.id != widget.selectedSlot?.id ||
        oldWidget.selectedSlot?.name != widget.selectedSlot?.name ||
        oldWidget.selectedSlot?.manufacturer !=
            widget.selectedSlot?.manufacturer ||
        oldWidget.selectedSlot?.category != widget.selectedSlot?.category ||
        oldWidget.selectedSlot?.isSoldOut != widget.selectedSlot?.isSoldOut) {
      _applySlot(widget.selectedSlot);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _manufacturerFreeController.dispose();
    _categoryFreeController.dispose();
    super.dispose();
  }

  void _applySlot(DrinkSlot? slot) {
    _selectedManufacturer = slot?.manufacturer;
    _selectedCategory = slot?.category;
    _isSoldOut = slot?.isSoldOut ?? false;

    _nameController.text = slot?.name ?? '';
    _manufacturerFreeController.text = slot?.manufacturer ?? '';
    _categoryFreeController.text = slot?.category ?? '';
    _searchController.clear();

    final manufacturerKnown = slot?.manufacturer != null &&
        _manufacturers.contains(slot!.manufacturer);
    final categoryKnown =
        slot?.category != null && _categories.contains(slot!.category);

    _useFreeInput = !(manufacturerKnown && categoryKnown);

    if (mounted) {
      setState(() {});
    }
  }

  void _save() {
    final slot = widget.selectedSlot;
    if (slot == null) return;

    final manufacturer = _useFreeInput
        ? _manufacturerFreeController.text.trim()
        : (_selectedManufacturer ?? '').trim();
    final category = _useFreeInput
        ? _categoryFreeController.text.trim()
        : (_selectedCategory ?? '').trim();
    final name = _nameController.text.trim();

    final updated = slot.copyWith(
      manufacturer: manufacturer.isEmpty ? null : manufacturer,
      category: category.isEmpty ? null : category,
      name: name.isEmpty ? null : name,
      isSoldOut: _isSoldOut,
    );

    widget.onSave(updated);
  }

  void _delete() {
    final slot = widget.selectedSlot;
    if (slot == null) return;

    widget.onDelete(
      slot.copyWith(
        clearManufacturer: true,
        clearCategory: true,
        clearName: true,
        isSoldOut: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.selectedSlot;

    if (slot == null) {
      return const _PanelFrame(
        child: Center(
          child: Text(
            '上の枠をタップすると、ここで商品を編集できます。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Noto Sans JP',
              fontSize: 14,
              color: Color(0xFF60707A),
            ),
          ),
        ),
      );
    }

    return _PanelFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '編集中: ${slot.page + 1}ページ ${slot.indexInPage + 1}番',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!_isEditable)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF3F5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '閲覧のみ',
                    style: TextStyle(
                      fontFamily: 'Noto Sans JP',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: IgnorePointer(
              ignoring: !_isEditable,
              child: Opacity(
                opacity: _isEditable ? 1 : 0.72,
                child: ListView(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _useFreeInput = false;
                              });
                            },
                            icon: const Icon(Icons.grid_view_rounded),
                            label: const Text('ボタン選択'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: !_useFreeInput
                                  ? const Color(0xFFEAF6F7)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _useFreeInput = true;
                              });
                            },
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text('自由入力'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor:
                              _useFreeInput ? const Color(0xFFEAF6F7) : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (!_useFreeInput) ...<Widget>[
                      const _SectionLabel(text: 'メーカー'),
                      const SizedBox(height: 8),
                      _LargeChoiceGrid(
                        items: _manufacturers,
                        selectedValue: _selectedManufacturer,
                        onSelected: (value) {
                          setState(() {
                            _selectedManufacturer = value;
                            _manufacturerFreeController.text = value;
                            _searchController.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 14),

                      const _SectionLabel(text: '種類'),
                      const SizedBox(height: 8),
                      _LargeChoiceGrid(
                        items: _categories,
                        selectedValue: _selectedCategory,
                        onSelected: (value) {
                          setState(() {
                            _selectedCategory = value;
                            _categoryFreeController.text = value;
                            _searchController.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 14),

                      const _SectionLabel(text: '商品候補'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontFamily: 'Noto Sans JP',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1F2A30),
                        ),
                        decoration: const InputDecoration(
                          hintText: '候補を絞り込む',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (_selectedManufacturer == null ||
                          _selectedCategory == null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F6F8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE3E7EB)),
                          ),
                          child: const Text(
                            '先にメーカーと種類を選ぶと、商品候補が表示されます。',
                            style: TextStyle(
                              fontFamily: 'Noto Sans JP',
                              fontSize: 13,
                              color: Color(0xFF60707A),
                            ),
                          ),
                        )
                      else if (_candidateProducts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F6F8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE3E7EB)),
                          ),
                          child: const Text(
                            '候補がありません。自由入力に切り替えて登録できます。',
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
                          children: _candidateProducts.map((candidate) {
                            final selected =
                                _nameController.text.trim() == candidate;
                            return ChoiceChip(
                              label: Text(candidate),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  _nameController.text = candidate;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _nameController,
                        style: const TextStyle(
                          fontFamily: 'Noto Sans JP',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1F2A30),
                        ),
                        decoration: const InputDecoration(
                          labelText: '商品名',
                          hintText: '候補から選ぶか、直接修正できます',
                        ),
                      ),
                    ] else ...<Widget>[
                      const _SectionLabel(text: '自由入力'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _manufacturerFreeController,
                        style: const TextStyle(
                          fontFamily: 'Noto Sans JP',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1F2A30),
                        ),
                        decoration: const InputDecoration(
                          labelText: 'メーカー名',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedManufacturer =
                            value.trim().isEmpty ? null : value.trim();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _categoryFreeController,
                        style: const TextStyle(
                          fontFamily: 'Noto Sans JP',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1F2A30),
                        ),
                        decoration: const InputDecoration(
                          labelText: '種類',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory =
                            value.trim().isEmpty ? null : value.trim();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(
                          fontFamily: 'Noto Sans JP',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1F2A30),
                        ),
                        decoration: const InputDecoration(
                          labelText: '商品名',
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: _isSoldOut,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '売り切れにする',
                        style: TextStyle(
                          fontFamily: 'Noto Sans JP',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _isSoldOut = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _delete,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('削除'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('保存'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeChoiceGrid extends StatelessWidget {
  const _LargeChoiceGrid({
    required this.items,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<String> items;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.25,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = item == selectedValue;

        return InkWell(
          onTap: () => onSelected(item),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEAF6F7) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFFE3E7EB),
                width: selected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  item,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Noto Sans JP',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : const Color(0xFF334148),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PanelFrame extends StatelessWidget {
  const _PanelFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE3E7EB)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Noto Sans JP',
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Color(0xFF334148),
      ),
    );
  }
}