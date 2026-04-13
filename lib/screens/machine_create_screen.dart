import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/user_progress_service.dart';
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
  final TextEditingController _memoController = TextEditingController();

  bool _isSaving = false;
  bool _isLoadingLocation = true;

  double? _lat;
  double? _lng;

  String? _selectedManufacturer;

  final Set<String> _selectedTags = <String>{};
  final Set<String> _selectedProducts = <String>{};

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

  static const List<String> _commonTags = <String>[
    'お茶',
    'コーヒー',
    '炭酸',
    '水',
    'ジュース',
    'スポーツドリンク',
    'エナジー',
    'ホット',
    '冷たい',
    '無糖',
    '微糖',
    '加糖',
    'カフェイン',
    '電子決済可',
    '現金のみ',
    'ゴミ箱あり',
  ];

  static const Map<String, List<String>> _manufacturerProducts =
  <String, List<String>>{
    'コカ・コーラ': <String>[
      '綾鷹',
      '爽健美茶',
      'いろはす',
      'ジョージア ブラック',
      'ジョージア カフェオレ',
      'コカ・コーラ',
      'ゼロシュガー',
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
      'ペプシ',
      'デカビタC',
      'なっちゃん',
      '天然水',
      'GREEN DA・KA・RA',
      '烏龍茶',
      'CCレモン',
      'BOSS レインボーマウンテン',
      'BOSS 贅沢微糖',
    ],
    '伊藤園': <String>[
      'お〜いお茶 緑茶',
      'お〜いお茶 濃い茶',
      '健康ミネラルむぎ茶',
      'TULLY\'S BLACK',
      'TULLY\'S LATTE',
      '充実野菜',
      'ニッポンエール',
      'Evian',
      'Relax ジャスミンティー',
      'お〜いお茶 ほうじ茶',
      'ビタミン野菜',
      '理想のトマト',
    ],
    'キリン': <String>[
      '生茶',
      '午後の紅茶 ミルクティー',
      '午後の紅茶 ストレート',
      'FIRE ブラック',
      'FIRE 微糖',
      'キリンレモン',
      'メッツ コーラ',
      '世界のKitchenから',
      '天然水',
      '小岩井 純水果汁',
      'iMUSE',
      'トロピカーナ',
    ],
    'アサヒ': <String>[
      '十六茶',
      'ウィルキンソン タンサン',
      'カルピスウォーター',
      'カルピスソーダ',
      'ワンダ モーニングショット',
      'ワンダ 金の微糖',
      '三ツ矢サイダー',
      'おいしい水',
      'MATCH',
      'ドデカミン',
      'バヤリース オレンジ',
      '颯',
    ],
    'ダイドー': <String>[
      'ダイドーブレンド',
      '世界一のバリスタ 微糖',
      '葉の茶',
      'miu',
      'さらっとしぼったオレンジ',
      '梅よろし',
      'ぷるシャリ温州みかん',
      'デミタス ブラック',
      'デミタス 微糖',
      '和果ごこち',
      '贅沢香茶',
      '復刻堂 コーヒー',
    ],
    '大塚製薬': <String>[
      'ポカリスエット',
      'イオンウォーター',
      'オロナミンC',
      'ボディメンテ',
      'エネルゲン',
      'MATCH',
      'ファイブミニ',
      'カロリーメイトゼリー',
      'ソイジョイドリンク',
      'ジャワティー',
      'シンビーノ',
      'ポカリ缶',
    ],
    'AQUO': <String>[
      'AQUO Water',
      'AQUO Soda',
      'AQUO Coffee Black',
      'AQUO Cafe Latte',
      'AQUO Green Tea',
      'AQUO Lemon',
      'AQUO Energy',
      'AQUO Milk Tea',
      'AQUO Sports',
      'AQUO Orange',
      'AQUO Oolong',
      'AQUO Sparkling',
    ],
    'その他': <String>[
      '緑茶',
      '麦茶',
      '水',
      'ブラックコーヒー',
      'カフェオレ',
      '炭酸飲料',
      'スポーツドリンク',
      'オレンジジュース',
      'りんごジュース',
      'ミルクティー',
      'エナジードリンク',
      'ほうじ茶',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationNameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final position = await DistanceUtil.getCurrentPositionSafe();

      if (!mounted) return;

      setState(() {
        _lat = position?.latitude;
        _lng = position?.longitude;
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  List<String> get _presetProducts {
    final manufacturer = _selectedManufacturer;
    if (manufacturer == null) return const <String>[];
    return _manufacturerProducts[manufacturer] ?? const <String>[];
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

  void _toggleProduct(String product) {
    setState(() {
      if (_selectedProducts.contains(product)) {
        _selectedProducts.remove(product);
      } else {
        _selectedProducts.add(product);
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ログイン後に登録してください。'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedManufacturer == null || _selectedManufacturer!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メーカーを選択してください。'),
        ),
      );
      return;
    }

    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('位置情報を取得してから登録してください。'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final now = Timestamp.now();
      final machines = FirebaseFirestore.instance.collection('vending_machines');
      final newDoc = machines.doc();

      final displayName = _buildDisplayName(user);

      final productMaps = _selectedProducts
          .map(
            (name) => <String, dynamic>{
          'name': name,
          'tags': _guessTagsFromProductName(name),
        },
      )
          .toList();

      final machineData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'manufacturer': _selectedManufacturer!.trim(),
        'location': <String, dynamic>{
          'lat': _lat,
          'lng': _lng,
        },
        'lat': _lat,
        'lng': _lng,
        'locationName': _locationNameController.text.trim(),
        'memo': _memoController.text.trim(),
        'tags': _selectedTags.toList(),
        'products': productMaps,
        'drinks': _selectedProducts.toList(),
        'createdAt': now,
        'updatedAt': now,
        'createdBy': user.uid,
        'createdByName': displayName,
        'updatedBy': user.uid,
        'updatedByName': displayName,
      };

      await newDoc.set(machineData);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        <String, dynamic>{
          'displayName': displayName,
          'favoriteDrinkNoticeEnabled': true,
          'machineUpdateNoticeEnabled': false,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      await UserProgressService.applyMachineRegisterProgress(
        uid: user.uid,
        displayName: displayName,
        addedDrinkCount: _selectedProducts.length,
      );

      if (!mounted) return;

      Navigator.of(context).pop(<String, dynamic>{
        'created': true,
        'machineId': newDoc.id,
        'openDetail': true,
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存に失敗しました: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  String _buildDisplayName(User user) {
    final fromProfile = (user.displayName ?? '').trim();
    if (fromProfile.isNotEmpty) return fromProfile;

    final fromEmail = (user.email ?? '').trim();
    if (fromEmail.isNotEmpty) return fromEmail;

    return 'ユーザー';
  }

  List<String> _guessTagsFromProductName(String name) {
    final lower = name.toLowerCase();
    final tags = <String>{};

    if (name.contains('茶') ||
        name.contains('烏龍') ||
        name.contains('ジャスミン')) {
      tags.add('お茶');
    }
    if (name.contains('コーヒー') ||
        name.contains('BLACK') ||
        name.contains('ブラック') ||
        name.contains('BOSS') ||
        name.contains('FIRE') ||
        name.contains('ジョージア') ||
        name.contains('ワンダ') ||
        lower.contains('coffee')) {
      tags.add('コーヒー');
      tags.add('カフェイン');
    }
    if (name.contains('炭酸') ||
        name.contains('コーラ') ||
        name.contains('サイダー') ||
        name.contains('ソーダ') ||
        lower.contains('sparkling')) {
      tags.add('炭酸');
    }
    if (name.contains('水') ||
        lower.contains('water') ||
        name.contains('天然水') ||
        name.contains('いろはす')) {
      tags.add('水');
    }
    if (name.contains('ラテ') ||
        name.contains('カフェオレ') ||
        name.contains('ミルク')) {
      tags.add('加糖');
    }
    if (name.contains('無糖') ||
        name.contains('BLACK') ||
        name.contains('ブラック')) {
      tags.add('無糖');
    }
    if (name.contains('微糖')) {
      tags.add('微糖');
    }
    if (name.contains('エナジー') ||
        name.contains('リアルゴールド') ||
        name.contains('デカビタ') ||
        name.contains('ドデカミン')) {
      tags.add('エナジー');
      tags.add('カフェイン');
    }
    if (name.contains('ポカリ') ||
        name.contains('アクエリアス') ||
        name.contains('スポーツ')) {
      tags.add('スポーツドリンク');
    }
    if (name.contains('ジュース') ||
        name.contains('オレンジ') ||
        name.contains('りんご') ||
        name.contains('Qoo') ||
        name.contains('なっちゃん') ||
        name.contains('バヤリース')) {
      tags.add('ジュース');
    }

    return tags.toList();
  }

  Widget _buildManufacturerSection() {
    return _SectionCard(
      title: 'メーカー',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _manufacturers.map((manufacturer) {
          final selected = _selectedManufacturer == manufacturer;
          return ChoiceChip(
            label: Text(manufacturer),
            selected: selected,
            onSelected: (_) {
              setState(() {
                if (_selectedManufacturer == manufacturer) {
                  _selectedManufacturer = null;
                  _selectedProducts.clear();
                } else {
                  _selectedManufacturer = manufacturer;
                  _selectedProducts.clear();
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductSection() {
    final products = _presetProducts;

    return _SectionCard(
      title: 'ドリンク登録',
      subtitle: '見かけたものだけでOK / あとで追加できます',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedManufacturer == null)
            const Text(
              '先にメーカーを選択してください。',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF60707A),
              ),
            )
          else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.08,
              ),
              itemBuilder: (context, index) {
                final product = products[index];
                final selected = _selectedProducts.contains(product);

                return InkWell(
                  onTap: () => _toggleProduct(product),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                      selected ? const Color(0xFFE8F5FF) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFFE3E7EB),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        product,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w700,
                          color: const Color(0xFF334148),
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Text(
              _selectedProducts.isEmpty
                  ? '未選択でも保存できます。'
                  : '${_selectedProducts.length}件選択中',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF60707A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagSection() {
    return _SectionCard(
      title: 'タグ',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _commonTags.map((tag) {
          final selected = _selectedTags.contains(tag);
          return FilterChip(
            label: Text(tag),
            selected: selected,
            onSelected: (_) => _toggleTag(tag),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationText = (_lat != null && _lng != null)
        ? '緯度 ${_lat!.toStringAsFixed(6)} / 経度 ${_lng!.toStringAsFixed(6)}'
        : '位置情報を取得できていません';

    return Scaffold(
      backgroundColor: const Color(0xFFD6ECFF),
      appBar: AppBar(
        title: const Text('自販機登録'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              _SectionCard(
                title: '位置',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            locationText,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF60707A),
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed:
                          _isLoadingLocation ? null : _loadCurrentLocation,
                          icon: _isLoadingLocation
                              ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                              : const Icon(Icons.my_location_rounded),
                          label: Text(_isLoadingLocation ? '取得中' : '再取得'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _locationNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '場所メモ',
                        hintText: '例: 駅前 / 1階入口付近 / コンビニ横',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: '基本情報',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '自販機名',
                        hintText: '例: 駅前の赤い自販機',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return '自販機名を入力してください。';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildManufacturerSection(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _memoController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'メモ',
                        hintText: '例: ホット多め / 少し奥まっている / 夜でも明るい',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildProductSection(),
              const SizedBox(height: 12),
              _buildTagSection(),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF0D8A8)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: Color(0xFF7A5A17),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'あとで編集できます。ドリンク未登録でもOKです。見かけたものだけ選んで保存してください。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xFF6B5420),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.save_rounded),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(_isSaving ? '保存中...' : '保存する'),
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
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final Widget child;
  final String? subtitle;

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
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF60707A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}