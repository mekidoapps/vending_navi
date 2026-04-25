import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/drink_slot_data.dart';

class DrinkRegistrationScreen extends StatefulWidget {
  const DrinkRegistrationScreen({
    super.key,
    required this.initialSlots,
    this.manufacturer,
  });

  final List<DrinkSlotData> initialSlots;
  final String? manufacturer;

  @override
  State<DrinkRegistrationScreen> createState() =>
      _DrinkRegistrationScreenState();
}

class _DrinkRegistrationScreenState extends State<DrinkRegistrationScreen> {
  static const int _slotCount = 12;

  static const List<String> _commonSuggestions = <String>[
    'お〜いお茶',
    '綾鷹',
    'BOSS ブラック',
    'ジョージア ブラック',
    '午後の紅茶 ミルクティー',
    'いろはす',
    'コカ・コーラ',
    '天然水',
    'アクエリアス',
    'ポカリスエット',
    'CCレモン',
    '三ツ矢サイダー',
  ];

  static const Map<String, List<String>> _manufacturerPresets =
  <String, List<String>>{
    'コカ・コーラ': <String>[
      '綾鷹',
      '爽健美茶',
      'いろはす',
      'ジョージア ブラック',
      'ジョージア カフェオレ',
      'コカ・コーラ',
      'コカ・コーラ ゼロ',
      'ファンタ グレープ',
      'アクエリアス',
      'リアルゴールド',
      'Qoo りんご',
      '紅茶花伝',
    ],
    'サントリー': <String>[
      '伊右衛門',
      'クラフトボス ブラック',
      'クラフトボス ラテ',
      'BOSS レインボーマウンテン',
      'BOSS 贅沢微糖',
      'ペプシ',
      'デカビタC',
      'なっちゃん',
      '天然水',
      'GREEN DA・KA・RA',
      '烏龍茶',
      'CCレモン',
    ],
    '伊藤園': <String>[
      'お〜いお茶 緑茶',
      'お〜いお茶 濃い茶',
      '健康ミネラルむぎ茶',
      '充実野菜',
      'TULLY’S COFFEE BLACK',
      'TULLY’S COFFEE LATTE',
      '天然水',
      'ビタミン野菜',
      '黒豆茶',
      'ジャスミン茶',
      'ほうじ茶',
      '理想のトマト',
    ],
    'キリン': <String>[
      '生茶',
      '午後の紅茶 ストレートティー',
      '午後の紅茶 ミルクティー',
      '午後の紅茶 レモンティー',
      'キリンレモン',
      'FIRE ブラック',
      'FIRE カフェオレ',
      '世界のKitchenから ソルティライチ',
      'アルカリイオンの水',
      'メッツ',
      '小岩井 純水果汁',
      '生茶 ほうじ煎茶',
    ],
    'アサヒ': <String>[
      'ワンダ モーニングショット',
      'ワンダ 金の微糖',
      '十六茶',
      '三ツ矢サイダー',
      'カルピスウォーター',
      'カルピスソーダ',
      'ウィルキンソン タンサン',
      '颯',
      'おいしい水',
      'バヤリース オレンジ',
      'モンスター',
      '守る働く乳酸菌',
    ],
    'ダイドー': <String>[
      'ダイドーブレンド',
      'ダイドーブレンド 微糖',
      'デミタスコーヒー',
      '葉の茶',
      'ミスティオ',
      'さらっとしぼったオレンジ',
      '和果ごこち ゆずれもん',
      '燕龍茶レベルケア',
      '梅よろし',
      '贅沢香茶',
      'アイスコーヒー',
      'カフェオレ',
    ],
    '大塚製薬': <String>[
      'ポカリスエット',
      'ポカリスエット イオンウォーター',
      'オロナミンC',
      'ボディメンテ',
      'MATCH',
      'エネルゲン',
      'ファイブミニ',
      'シンビーノ',
      'ジャワティー',
      'カロリーメイトゼリー',
      'ソイジョイ ドリンク',
      'オロナミンC ドリンク',
    ],
    'AQUO': <String>[
      '天然水',
      '綾鷹',
      'お〜いお茶',
      'BOSS ブラック',
      'ジョージア ブラック',
      '午後の紅茶 ミルクティー',
      'ポカリスエット',
      'アクエリアス',
      'コカ・コーラ',
      '三ツ矢サイダー',
      'CCレモン',
      'いろはす',
    ],
    'その他': <String>[
      'お〜いお茶',
      '綾鷹',
      'BOSS ブラック',
      'ジョージア ブラック',
      '午後の紅茶 ミルクティー',
      '天然水',
      'いろはす',
      'コカ・コーラ',
      '三ツ矢サイダー',
      'ポカリスエット',
      'アクエリアス',
      'CCレモン',
    ],
  };

  late List<DrinkSlotData> _slots;
  String? _selectedManufacturer;
  bool _isPopping = false;
  bool _showGuide = false;

  @override
  void initState() {
    super.initState();
    _selectedManufacturer = _normalizeManufacturer(widget.manufacturer);
    _slots = List<DrinkSlotData>.generate(
      _slotCount,
          (int index) {
        if (index < widget.initialSlots.length) {
          return widget.initialSlots[index];
        }
        return const DrinkSlotData();
      },
    );
    _loadGuideState();
  }

  Future<void> _loadGuideState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool seen = prefs.getBool('drink_register_guide_seen') ?? false;

    if (!seen && mounted) {
      setState(() {
        _showGuide = true;
      });
    }
  }

  Future<void> _dismissGuide() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('drink_register_guide_seen', true);

    if (!mounted) return;

    setState(() {
      _showGuide = false;
    });
  }

  Future<void> _hideGuideIfNeeded() async {
    if (!_showGuide) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('drink_register_guide_seen', true);

    if (!mounted) return;

    setState(() {
      _showGuide = false;
    });
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

  List<String> get _presetCandidates {
    final String maker = _selectedManufacturer ?? 'その他';
    final List<String> preset =
        _manufacturerPresets[maker] ?? _commonSuggestions;

    final Set<String> used = <String>{};
    final List<String> merged = <String>[
      ...preset,
      ..._commonSuggestions,
    ];

    return merged.where((String name) {
      final String trimmed = name.trim();
      if (trimmed.isEmpty) return false;
      if (used.contains(trimmed)) return false;
      used.add(trimmed);
      return true;
    }).toList(growable: false);
  }

  int get _registeredCount =>
      _slots.where((DrinkSlotData slot) => slot.hasName).length;

  Future<void> _editSlot(int index) async {
    final DrinkSlotData current = _slots[index];

    final DrinkSlotData? result = await showModalBottomSheet<DrinkSlotData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return _DrinkSlotEditSheet(
          slotIndex: index,
          initialValue: current,
          manufacturer: _selectedManufacturer,
          presetCandidates: _presetCandidates,
        );
      },
    );

    if (!mounted || result == null) return;

    await _hideGuideIfNeeded();

    if (!mounted) return;

    setState(() {
      _slots[index] = result;
    });
  }

  Future<void> _fillWithPresetGrid() async {
    final List<String> presets = _presetCandidates.take(_slotCount).toList();

    await _hideGuideIfNeeded();

    if (!mounted) return;

    setState(() {
      _slots = List<DrinkSlotData>.generate(_slotCount, (int index) {
        if (index < presets.length) {
          return DrinkSlotData(name: presets[index]);
        }
        return const DrinkSlotData();
      });
    });
  }

  List<DrinkSlotData> _normalizedResult() {
    return List<DrinkSlotData>.generate(
      _slotCount,
          (int index) =>
      index < _slots.length ? _slots[index] : const DrinkSlotData(),
      growable: false,
    );
  }

  void _popWithSave() {
    if (_isPopping || !mounted) return;
    _isPopping = true;

    final List<DrinkSlotData> result = _normalizedResult();
    Navigator.of(context).pop(result);
  }

  Future<bool> _handleWillPop() async {
    _popWithSave();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFEAF6FF),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _popWithSave,
          ),
          title: const Text('ドリンク登録'),
          actions: <Widget>[
            TextButton(
              onPressed: _popWithSave,
              child: const Text('保存'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE3E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _selectedManufacturer == null
                            ? '見かけたものだけでOK'
                            : '$_selectedManufacturer の候補から選べます',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF334148),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'あとで追加できます。未登録の段があっても大丈夫です。',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF60707A),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _fillWithPresetGrid,
                              icon: const Icon(Icons.grid_view_rounded),
                              label: const Text('候補を一気に入れる'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '登録済み $_registeredCount / $_slotCount',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF60707A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_showGuide)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFE0A3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(
                          Icons.lightbulb_outline,
                          size: 20,
                          color: Color(0xFF8A5B00),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '見かけた商品だけでOK\n全部埋めなくて大丈夫\nあとから追加できます',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7A6642),
                              height: 1.6,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _dismissGuide,
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Color(0xFF8A5B00),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.70,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _slots.length,
                  itemBuilder: (BuildContext context, int index) {
                    final DrinkSlotData slot = _slots[index];
                    return _DrinkSlotCard(
                      index: index,
                      slot: slot,
                      onTap: () => _editSlot(index),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrinkSlotEditSheet extends StatefulWidget {
  const _DrinkSlotEditSheet({
    required this.slotIndex,
    required this.initialValue,
    required this.presetCandidates,
    required this.manufacturer,
  });

  final int slotIndex;
  final DrinkSlotData initialValue;
  final List<String> presetCandidates;
  final String? manufacturer;

  @override
  State<_DrinkSlotEditSheet> createState() => _DrinkSlotEditSheetState();
}

class _DrinkSlotEditSheetState extends State<_DrinkSlotEditSheet> {
  late final TextEditingController _controller;
  late bool _soldOut;
  late Set<String> _selectedTags;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.name ?? '');
    _soldOut = widget.initialValue.isSoldOut;
    _selectedTags = <String>{...widget.initialValue.tags};
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyPreset(String name) {
    if (_isClosing) return;
    setState(() {
      _controller.text = name;
    });
  }

  Future<void> _closeWithResult(DrinkSlotData result) async {
    if (_isClosing) return;
    _isClosing = true;

    FocusScope.of(context).unfocus();

    await Future<void>.delayed(const Duration(milliseconds: 16));

    if (!mounted) return;

    Navigator.of(context).pop(result);
  }

  Future<void> _clearSlot() async {
    await _closeWithResult(
      const DrinkSlotData(
        name: null,
        tags: <String>[],
        isSoldOut: false,
      ),
    );
  }

  Future<void> _submit() async {
    final String trimmed = _controller.text.trim();

    await _closeWithResult(
      DrinkSlotData(
        name: trimmed.isEmpty ? null : trimmed,
        tags: _selectedTags.toList(growable: false),
        isSoldOut: _soldOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'スロット ${widget.slotIndex + 1}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.manufacturer == null
                    ? 'メーカー未選択でも登録できます'
                    : '${widget.manufacturer} の候補から選べます',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF60707A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                autofocus: true,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'ドリンク名',
                  hintText: '例）綾鷹 / BOSS ブラック',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE3E7EB)),
                ),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '売り切れ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334148),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'その段だけ売り切れにする',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF60707A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _soldOut,
                      onChanged: _isClosing
                          ? null
                          : (bool value) {
                        setState(() {
                          _soldOut = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'メーカー候補',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.presetCandidates.map((String name) {
                  final bool selected = _controller.text.trim() == name.trim();
                  return ChoiceChip(
                    label: Text(name),
                    selected: selected,
                    onSelected: _isClosing ? null : (_) => _applyPreset(name),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'タグ',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tagOptions.map((String tag) {
                  final bool selected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: _isClosing
                        ? null
                        : (bool value) {
                      setState(() {
                        if (value) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isClosing ? null : _clearSlot,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('この段を空にする'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isClosing ? null : _submit,
                      child: const Text('この内容で反映'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrinkSlotCard extends StatelessWidget {
  const _DrinkSlotCard({
    required this.index,
    required this.slot,
    required this.onTap,
  });

  final int index;
  final DrinkSlotData slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasName = slot.hasName;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3E7EB)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.topRight,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8A98A3),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: hasName
                        ? const Color(0xFFF6FBFF)
                        : const Color(0xFFF7F9FB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasName
                          ? const Color(0xFFD5E8F7)
                          : const Color(0xFFE3E7EB),
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: hasName
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (slot.isSoldOut)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F0),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFFFD7D2),
                            ),
                          ),
                          child: const Text(
                            '売切',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD94841),
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        slot.name!.trim(),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                          color: slot.isSoldOut
                              ? const Color(0xFF7E8A92)
                              : const Color(0xFF334148),
                        ),
                      ),
                      if (slot.tags.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: slot.tags.take(2).map((String tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF6FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4B6472),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  )
                      : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.add_circle_outline_rounded,
                          color: Color(0xFF8A98A3),
                          size: 28,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '未登録',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A98A3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const List<String> _tagOptions = <String>[
  'お茶',
  'コーヒー',
  '炭酸',
  '水',
  'ジュース',
  'スポーツ',
  'エナジー',
  'ホット',
  '無糖',
  '微糖',
  '加糖',
  'カフェイン',
];