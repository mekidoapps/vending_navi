import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/drink_slot_data.dart';
import '../services/user_progress_service.dart';
import '../utils/distance_util.dart';
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

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  bool _isLoadingLocation = false;
  bool _isLoadingMachine = false;
  bool _isSaving = false;

  double? _latitude;
  double? _longitude;
  String? _locationError;

  String? _selectedManufacturer;
  final Set<String> _selectedTags = <String>{};

  int _initialRegisteredDrinkCount = 0;
  List<DrinkSlotData> _drinkSlots = List<DrinkSlotData>.generate(
    12,
    (_) => const DrinkSlotData(),
  );

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

  bool get _canSave {
    return !_isSaving &&
        !_isLoadingMachine &&
        _latitude != null &&
        _longitude != null &&
        _hasManufacturer;
  }

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadExistingMachine();
    } else {
      _loadCurrentLocation();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _memoController.dispose();
    super.dispose();
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

  double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> _loadCurrentLocation() async {
    if (_isLoadingLocation) return;

    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final position = await DistanceUtil.getCurrentPositionSafe();
      if (!mounted) return;

      setState(() {
        _latitude = position?.latitude;
        _longitude = position?.longitude;
        if (position == null) {
          _locationError = '位置情報を取得できませんでした。権限を確認してください。';
        }
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

  Future<void> _loadExistingMachine() async {
    if (!_isEditMode) return;

    setState(() {
      _isLoadingMachine = true;
      _locationError = null;
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
      final Map<String, dynamic>? location = data['location'] is Map
          ? Map<String, dynamic>.from(data['location'] as Map)
          : null;
      final List<DrinkSlotData> loadedSlots = _slotsFromMachineData(data);

      setState(() {
        _nameController.text = data['name']?.toString() ?? '';
        _memoController.text = data['memo']?.toString() ?? '';
        _selectedManufacturer =
            _normalizeManufacturer(data['manufacturer']?.toString());
        _selectedTags
          ..clear()
          ..addAll(_stringList(data['tags']));
        _latitude = _readDouble(data['lat']) ?? _readDouble(location?['lat']);
        _longitude = _readDouble(data['lng']) ?? _readDouble(location?['lng']);
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
    final List<DrinkSlotData> base = List<DrinkSlotData>.generate(
      12,
      (_) => const DrinkSlotData(),
    );

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

  void _selectManufacturer(String manufacturer) {
    setState(() {
      _selectedManufacturer =
          _selectedManufacturer == manufacturer ? null : manufacturer;
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

    setState(() {
      _drinkSlots = List<DrinkSlotData>.generate(
        12,
        (int i) => i < result.length ? result[i] : const DrinkSlotData(),
      );
    });
  }

  String _buildDisplayName(User user) {
    final String fromProfile = (user.displayName ?? '').trim();
    if (fromProfile.isNotEmpty) return fromProfile;

    final String fromEmail = (user.email ?? '').trim();
    if (fromEmail.isNotEmpty) return fromEmail;

    return 'ユーザー';
  }

  String _buildMachineName() {
    final String input = _nameController.text.trim();
    if (input.isNotEmpty) return input;

    final String manufacturer = _selectedManufacturer ?? '自販機';
    return '$manufacturerの自販機';
  }

  Future<ProgressApplyResult> _applyProgressAfterCreate() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return ProgressApplyResult.empty();
    }

    return UserProgressService.instance.applyMachineRegisterProgress(
      uid: user.uid,
      displayName: _buildDisplayName(user),
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

    return UserProgressService.instance.applyDrinkRegisterProgress(
      uid: user.uid,
      displayName: _buildDisplayName(user),
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

  Future<void> _save() async {
    await _saveMachine(skippedDrinkRegistration: !_hasDrinks);
  }

  Future<void> _saveMachine({required bool skippedDrinkRegistration}) async {
    if (!_canSave) return;

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログイン後に登録してください。')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final String displayName = _buildDisplayName(user);
      final Timestamp now = Timestamp.now();
      final Map<String, dynamic> payload = <String, dynamic>{
        'name': _buildMachineName(),
        'manufacturer': _selectedManufacturer ?? 'その他',
        'memo': _memoController.text.trim(),
        'tags': _selectedTags.toList(growable: false),
        'lat': _latitude,
        'lng': _longitude,
        'location': <String, dynamic>{
          'lat': _latitude,
          'lng': _longitude,
        },
        'drinkSlots': _drinkSlots.map((DrinkSlotData e) => e.toMap()).toList(),
        'drinks': _registeredDrinkNames,
        'products': _drinkSlots
            .where((DrinkSlotData e) => e.hasName)
            .map(
              (DrinkSlotData e) => <String, dynamic>{
                'name': e.name,
                'tags': e.tags,
                'isSoldOut': e.isSoldOut,
              },
            )
            .toList(growable: false),
        'updatedAt': now,
        'updatedBy': user.uid,
        'updatedByName': displayName,
      };

      ProgressApplyResult progressResult;
      String machineId;

      if (_isEditMode) {
        machineId = widget.machineId!;
        await FirebaseFirestore.instance
            .collection('vending_machines')
            .doc(machineId)
            .set(payload, SetOptions(merge: true));
        progressResult = await _applyProgressAfterEdit();
      } else {
        final DocumentReference<Map<String, dynamic>> doc =
            FirebaseFirestore.instance.collection('vending_machines').doc();
        machineId = doc.id;
        await doc.set(<String, dynamic>{
          ...payload,
          'createdAt': now,
          'createdBy': user.uid,
          'createdByName': displayName,
        });

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          <String, dynamic>{
            'displayName': displayName,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );

        progressResult = await _applyProgressAfterCreate();
      }

      if (!mounted) return;

      await _showUnlockedTitlesIfNeeded(progressResult);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? (skippedDrinkRegistration
                    ? 'ドリンク未登録のまま更新しました'
                    : 'ドリンク情報を更新しました')
                : (skippedDrinkRegistration
                    ? 'ドリンク未登録で保存しました'
                    : '自販機情報を保存しました'),
          ),
        ),
      );

      Navigator.of(context).pop(<String, dynamic>{
        _isEditMode ? 'updated' : 'created': true,
        'machineId': machineId,
        'earnedTitles': progressResult.earnedTitles,
        'openDetail': true,
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

  Widget _buildLocationCard() {
    final String locationText = (_latitude != null && _longitude != null)
        ? '緯度 ${_latitude!.toStringAsFixed(6)} / 経度 ${_longitude!.toStringAsFixed(6)}'
        : '位置情報を取得できていません';

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '位置',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334148),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            locationText,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF60707A),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_locationError != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              _locationError!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFB3261E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (!_isEditMode) ...<Widget>[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isLoadingLocation ? null : _loadCurrentLocation,
              icon: _isLoadingLocation
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
              label: Text(_isLoadingLocation ? '取得中' : '現在地を再取得'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '基本情報',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334148),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '自販機名',
              hintText: '例：〇〇駅 南口前の自販機',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '名前は未入力でも保存できます。あとから調整できます。',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF60707A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManufacturerCard() {
    return _SectionCard(
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _manufacturers.map((String maker) {
              return ChoiceChip(
                label: Text(maker),
                selected: _selectedManufacturer == maker,
                onSelected: _isSaving ? null : (_) => _selectManufacturer(maker),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            _hasManufacturer
                ? '選択中メーカー: $_selectedManufacturer'
                : 'メーカーを選択してください',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF60707A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrinkCard() {
    return _SectionCard(
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
            child: Text(_hasDrinks ? 'ドリンクを編集する' : 'ドリンクを登録する'),
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
    );
  }

  Widget _buildTagCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'タグ（任意）',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334148),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tagOptions.map((String tag) {
              return FilterChip(
                label: Text(tag),
                selected: _selectedTags.contains(tag),
                onSelected: _isSaving ? null : (_) => _toggleTag(tag),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'メモ（任意）',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334148),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _memoController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '例：駅の改札近く / 建物の1階外 / 夜でも明るい など',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0D8A8)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      appBar: AppBar(
        title: Text(_isEditMode ? 'ドリンク登録 / 編集' : '自販機登録'),
        actions: <Widget>[
          TextButton(
            onPressed: _canSave ? _save : null,
            child: const Text('保存'),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingMachine
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _buildLocationCard(),
                  const SizedBox(height: 12),
                  _buildBasicInfoCard(),
                  const SizedBox(height: 12),
                  _buildManufacturerCard(),
                  const SizedBox(height: 12),
                  _buildDrinkCard(),
                  const SizedBox(height: 12),
                  _buildTagCard(),
                  const SizedBox(height: 12),
                  _buildMemoCard(),
                  const SizedBox(height: 16),
                  _buildNoticeCard(),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _canSave
                        ? () => _saveMachine(
                              skippedDrinkRegistration: !_hasDrinks,
                            )
                        : null,
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
                      child: Text(
                        _isSaving
                            ? '保存中...'
                            : _isEditMode
                                ? (_hasDrinks ? 'この内容で更新' : 'ドリンク未登録で更新')
                                : (_hasDrinks ? 'この内容で登録' : 'ドリンク未登録で登録'),
                      ),
                    ),
                  ),
                ],
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
        boxShadow: const <BoxShadow>[
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
