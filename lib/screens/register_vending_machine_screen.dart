import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/vending_machine.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/user_progress_service.dart';
import '../utils/drink_tag_util.dart';

class RegisterVendingMachineScreen extends StatefulWidget {
  const RegisterVendingMachineScreen({
    super.key,
  });

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

  static const List<String> _tagOptions = <String>[
    '屋内',
    '屋外',
    '駅',
    'コンビニ前',
    'オフィス街',
    '現金のみ',
    'キャッシュレス',
    'ホットあり',
    'ベンチ近く',
  ];

  static const Map<String, List<String>> _manufacturerDrinkPresets =
  <String, List<String>>{
    'コカ・コーラ': <String>[
      '綾鷹',
      '綾鷹 濃い緑茶',
      '爽健美茶',
      'い・ろ・は・す',
      'ジョージア ブラック',
      'ジョージア 微糖',
      'コカ・コーラ',
      'コカ・コーラ ゼロ',
      'ファンタ グレープ',
      'アクエリアス',
      'やかんの麦茶',
      'からだすこやか茶W',
    ],
    'サントリー': <String>[
      '伊右衛門',
      '伊右衛門 濃い味',
      'BOSS ブラック',
      'BOSS レインボーマウンテン',
      'クラフトボス ブラック',
      'クラフトボス ラテ',
      '天然水',
      'C.C.レモン',
      'ペプシ',
      'GREEN DA・KA・RA',
      '胡麻麦茶',
      'デカビタC',
    ],
    '伊藤園': <String>[
      'お〜いお茶 緑茶',
      'お〜いお茶 濃い茶',
      '健康ミネラルむぎ茶',
      'TULLY\'S COFFEE ブラック',
      'TULLY\'S COFFEE BARISTA\'S BLACK',
      '磨かれて、澄みきった日本の水',
      '充実野菜',
      'ほうじ茶',
    ],
    'キリン': <String>[
      '生茶',
      '生茶 ほうじ煎茶',
      '午後の紅茶 おいしい無糖',
      '午後の紅茶 ミルクティー',
      '午後の紅茶 ストレートティー',
      'FIRE ブラック',
      'FIRE 微糖',
      'キリンレモン',
      'メッツ コーラ',
      'アルカリイオンの水',
    ],
    'アサヒ': <String>[
      'ワンダ モーニングショット',
      'ワンダ 金の微糖',
      'ワンダ ブラック',
      '十六茶',
      '三ツ矢サイダー',
      'ウィルキンソン タンサン',
      'カルピスウォーター',
      'おいしい水 天然水',
      'ドデカミン',
    ],
    'ダイドー': <String>[
      'ダイドーブレンド',
      'ダイドーブレンド 微糖',
      'ダイドーブレンド ブラック',
      'miu',
      '葉の茶',
    ],
    '大塚製薬': <String>[
      'ポカリスエット',
      'ポカリスエット イオンウォーター',
      'MATCH',
      'オロナミンC',
      'ボディメンテ',
    ],
    'AQUO': <String>[
      'お茶',
      'コーヒー',
      '天然水',
      '炭酸飲料',
      'スポーツドリンク',
    ],
    'その他': <String>[
      'お茶',
      'コーヒー',
      '水',
      '炭酸飲料',
      'ジュース',
    ],
  };

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  final LocationService _locationService = LocationService();

  bool _isLoadingLocation = true;
  bool _isSaving = false;

  String? _selectedManufacturer;
  String? _locationError;
  String? _addressLabel;

  double? _latitude;
  double? _longitude;

  final Set<String> _selectedDrinks = <String>{};
  final Set<String> _selectedTags = <String>{};

  List<String> get _drinkCandidates {
    final manufacturer = _selectedManufacturer;
    if (manufacturer == null) return const <String>[];
    return _manufacturerDrinkPresets[manufacturer] ?? const <String>[];
  }

  bool get _canSave {
    return !_isSaving &&
        _latitude != null &&
        _longitude != null &&
        _selectedManufacturer != null &&
        _nameController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_refresh);
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.removeListener(_refresh);
    _nameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final result = await _locationService.getCurrentLocation();
      if (!mounted) return;

      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _addressLabel =
        result.addressLabel.trim().isEmpty ? null : result.addressLabel;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _toggleDrink(String drinkName) {
    setState(() {
      if (_selectedDrinks.contains(drinkName)) {
        _selectedDrinks.remove(drinkName);
      } else {
        _selectedDrinks.add(drinkName);
      }
    });
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

  Future<void> _save() async {
    if (!_canSave) return;

    final manufacturer = _selectedManufacturer!;
    final now = DateTime.now();

    setState(() {
      _isSaving = true;
    });

    try {
      final selectedProducts = _selectedDrinks.map((drinkName) {
        return <String, dynamic>{
          'name': drinkName,
          'tags': DrinkTagUtil.guessTags(drinkName),
        };
      }).toList();

      final machine = VendingMachine(
        id: '',
        lat: _latitude!,
        lng: _longitude!,
        name: _nameController.text.trim(),
        manufacturer: manufacturer,
        products: selectedProducts,
        createdAt: now,
        updatedAt: now,
        lastCheckedAt: now,
        checkinCount: 0,
        address: _addressLabel,
        locationName: _addressLabel,
        note: _memoController.text.trim().isEmpty
            ? null
            : _memoController.text.trim(),
        tags: _selectedTags.toList(),
        cashlessSupported: _selectedTags.contains('キャッシュレス'),
      );

      final createdMachineId =
      await FirestoreService.instance.createMachine(machine);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await UserProgressService.instance.applyMachineRegisterProgress(
          uid: user.uid,
          displayName: user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'ユーザー',
          addedDrinkCount: selectedProducts.length,
        );
      }

      if (!mounted) return;

      final openDetail = await _showCompletedSheet(
        drinkCount: selectedProducts.length,
      );

      if (!mounted) return;
      Navigator.of(context).pop(<String, dynamic>{
        'created': true,
        'machineId': createdMachineId,
        'openDetail': openDetail,
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('登録に失敗しました: $e'),
        ),
      );

      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<bool> _showCompletedSheet({
    required int drinkCount,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 44,
                  color: Color(0xFF3E7BFA),
                ),
                const SizedBox(height: 12),
                const Text(
                  '自販機を登録しました',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334148),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  drinkCount > 0
                      ? 'ドリンク $drinkCount 件も一緒に登録しました。'
                      : 'ドリンクはあとから追加できます。',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF60707A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('マップへ戻る'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('詳細を開く'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('自販機を登録'),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '位置',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingLocation)
                      const Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '現在地を取得しています…',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF60707A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (_latitude != null && _longitude != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FBFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE3E7EB),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '現在地を登録に使います',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF334148),
                              ),
                            ),
                            if ((_addressLabel ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                _addressLabel!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF60707A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              '緯度: ${_latitude!.toStringAsFixed(6)} / 経度: ${_longitude!.toStringAsFixed(6)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF60707A),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFF3B7AF),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '位置情報を取得できませんでした',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF8A3B2E),
                              ),
                            ),
                            if ((_locationError ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                _locationError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8A3B2E),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _isLoadingLocation ? null : _loadCurrentLocation,
                        icon: const Icon(Icons.my_location_rounded),
                        label: const Text('現在地を再取得'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '基本情報',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '自販機名',
                        hintText: '例：〇〇駅 南口前の自販機',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '名前はあとから調整できます。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF60707A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'メーカー',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _manufacturers.map((manufacturer) {
                        final selected = _selectedManufacturer == manufacturer;
                        return ChoiceChip(
                          label: Text(manufacturer),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _selectedManufacturer =
                              selected ? null : manufacturer;
                              _selectedDrinks.clear();
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ドリンク（任意）',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '見かけたものだけでOKです。あとで追加できます。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF60707A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_selectedManufacturer == null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FBFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE3E7EB),
                          ),
                        ),
                        child: const Text(
                          '先にメーカーを選ぶと、ドリンク候補が出ます。',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF60707A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _drinkCandidates.map((drink) {
                          final selected = _selectedDrinks.contains(drink);
                          return FilterChip(
                            label: Text(drink),
                            selected: selected,
                            onSelected: (_) => _toggleDrink(drink),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'タグ（任意）',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tagOptions.map((tag) {
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
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'メモ（任意）',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _memoController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '例：駅の改札近く / 建物の1階外 / 夜でも明るい など',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _canSave ? _save : null,
                icon: _isSaving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? '保存中…' : 'この内容で登録'),
              ),
              const SizedBox(height: 8),
              const Text(
                'ドリンク未登録でも保存できます。',
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
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}