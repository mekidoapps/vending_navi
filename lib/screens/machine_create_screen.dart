import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/machine_create_result.dart';
import '../services/firestore_service.dart';
import '../services/local_progress_service.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';

class MachineCreateScreen extends StatefulWidget {
  const MachineCreateScreen({super.key});

  @override
  State<MachineCreateScreen> createState() => _MachineCreateScreenState();
}

class _MachineCreateScreenState extends State<MachineCreateScreen> {
  final TextEditingController _memoController = TextEditingController();
  final TextEditingController _drinkSearchController = TextEditingController();
  final TextEditingController _machineNameController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final LocationService _locationService = LocationService();

  final List<String> _allDrinks = <String>[
    'お〜いお茶',
    '綾鷹',
    '伊右衛門',
    'ボス ブラック',
    'ジョージア',
    'コカ・コーラ',
    '午後の紅茶',
    '天然水',
    'ポカリスエット',
    'デカビタC',
  ];

  final Set<String> _selectedTags = <String>{
    '電子決済OK',
    '屋外',
  };

  final List<String> _selectedDrinks = <String>[
    'お〜いお茶',
    'ボス ブラック',
  ];

  final List<XFile> _pickedImages = <XFile>[];

  bool _isSubmitting = false;
  bool _isFetchingLocation = false;

  double? _latitude;
  double? _longitude;
  String _addressLabel = '';

  List<String> get _drinkSuggestions {
    final q = _drinkSearchController.text.trim();
    if (q.isEmpty) {
      return _allDrinks
          .where((e) => !_selectedDrinks.contains(e))
          .take(6)
          .toList();
    }
    return _allDrinks
        .where((e) => e.contains(q) && !_selectedDrinks.contains(e))
        .take(6)
        .toList();
  }

  int get _expectedExp {
    int total = 30;
    total += _pickedImages.length * 10;
    total += _selectedDrinks.length * 5;
    total += _selectedTags.length * 2;
    if (_latitude != null && _longitude != null) {
      total += 5;
    }
    return total;
  }

  @override
  void dispose() {
    _memoController.dispose();
    _drinkSearchController.dispose();
    _machineNameController.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    if (_pickedImages.length >= 3) {
      _showSnackBar('写真は3枚までです');
      return;
    }

    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() {
        _pickedImages.add(file);
      });

      _showSnackBar('写真を追加しました');
    } catch (_) {
      _showSnackBar('カメラを開けませんでした');
    }
  }

  Future<void> _pickFromGallery() async {
    final remain = 3 - _pickedImages.length;
    if (remain <= 0) {
      _showSnackBar('写真は3枚までです');
      return;
    }

    try {
      final List<XFile> files = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );

      if (files.isEmpty) return;

      setState(() {
        _pickedImages.addAll(files.take(remain));
      });

      _showSnackBar('写真を追加しました');
    } catch (_) {
      _showSnackBar('写真を選べませんでした');
    }
  }

  void _removeImageAt(int index) {
    if (index < 0 || index >= _pickedImages.length) return;

    setState(() {
      _pickedImages.removeAt(index);
    });

    _showSnackBar('写真を削除しました');
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

  void _addDrink(String name) {
    if (_selectedDrinks.contains(name)) return;
    setState(() {
      _selectedDrinks.add(name);
      _drinkSearchController.clear();
    });
  }

  void _removeDrink(String name) {
    setState(() {
      _selectedDrinks.remove(name);
    });
  }

  String _resolvePaymentLabel() {
    if (_selectedTags.contains('電子決済OK')) {
      return '電子決済OK';
    }
    if (_selectedTags.contains('現金のみ')) {
      return '現金のみ';
    }
    return '';
  }

  Future<void> _fetchCurrentLocation() async {
    if (_isFetchingLocation) return;

    setState(() {
      _isFetchingLocation = true;
    });

    try {
      final result = await _locationService.getCurrentLocation();

      if (!mounted) return;

      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _addressLabel = result.addressLabel;
        _isFetchingLocation = false;
      });

      _showSnackBar('現在地を取得しました');
    } on LocationServiceException catch (e) {
      if (!mounted) return;

      setState(() {
        _isFetchingLocation = false;
      });

      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isFetchingLocation = false;
      });

      _showSnackBar('位置情報を取得できませんでした');
    }
  }

  Future<List<String>> _uploadPhotos(String machineName) async {
    if (_pickedImages.isEmpty) {
      return <String>[];
    }

    final files = _pickedImages.map((e) => File(e.path)).toList();
    final key = machineName.trim().isEmpty
        ? 'machine'
        : machineName
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^\wぁ-んァ-ヶ一-龠ー]'), '');

    return _storageService.uploadMachinePhotos(
      files: files,
      machineKey: key.isEmpty ? 'machine' : key,
    );
  }

  String _buildAddressHint() {
    final memo = _memoController.text.trim();

    if (_addressLabel.isNotEmpty && memo.isNotEmpty) {
      return '$_addressLabel / $memo';
    }
    if (_addressLabel.isNotEmpty) {
      return _addressLabel;
    }
    if (memo.isNotEmpty) {
      return memo;
    }
    return '';
  }

  Future<void> _submit() async {
    if (_selectedDrinks.isEmpty) {
      _showSnackBar('ドリンクを1つ以上追加してください');
      return;
    }

    if (_latitude == null || _longitude == null) {
      await _fetchCurrentLocation();
      if (_latitude == null || _longitude == null) {
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final before = await LocalProgressService.load();
      final beforeLevel = before.level;

      final machineName = _machineNameController.text.trim().isEmpty
          ? '新しい自販機'
          : _machineNameController.text.trim();

      final uploadedPhotoUrls = await _uploadPhotos(machineName);

      final createdId = await _firestoreService.createMachineFromForm(
        machineName: machineName,
        addressHint: _buildAddressHint(),
        tags: _selectedTags.toList(),
        photoUrls: uploadedPhotoUrls,
        drinkNames: _selectedDrinks,
        paymentLabel: _resolvePaymentLabel(),
        latitude: _latitude!,
        longitude: _longitude!,
      );

      final updated = await LocalProgressService.addExp(_expectedExp);
      final leveledUp = updated.level > beforeLevel;

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              leveledUp ? 'レベルアップおめでとう！' : '登録ありがとう！',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              '+$_expectedExp EXP\n${_pickedImages.isNotEmpty ? '写真つき投稿ボーナスも入りました。' : 'また登録してみて。'}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop<MachineCreateResult>(
                    MachineCreateResult(
                      machineId: createdId,
                      machineName: machineName,
                      expGained: _expectedExp,
                      leveledUp: leveledUp,
                    ),
                  );
                },
                child: const Text('ホームへ戻る'),
              ),
            ],
          );
        },
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showSnackBar('保存に失敗しました');
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const tags = <String>[
      '電子決済OK',
      '現金のみ',
      'ゴミ箱あり',
      '屋内',
      '屋外',
      'ホットあり',
      '冷たいのみ',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('自販機を登録'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7EF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFD8B6),
                      ),
                    ),
                    child: Text(
                      '見込み +$_expectedExp EXP',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pickedImages.isNotEmpty
                          ? '写真つきでいい感じ'
                          : '写真があると見つけやすい',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isSubmitting || _isFetchingLocation) ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.add_business_rounded),
                  label: Text(_isSubmitting ? '登録中...' : 'この自販機を登録'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '新しい自販機を登録',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '見つけた自販機をみんなに共有しよう',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _CreateSectionCard(
                title: '自販機名',
                child: TextField(
                  controller: _machineNameController,
                  decoration: const InputDecoration(
                    hintText: '例：駅前ロータリー横の自販機',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _CreateSectionCard(
                title: '写真',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFromCamera,
                            icon: const Icon(Icons.photo_camera_rounded),
                            label: const Text('写真を撮る'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFromGallery,
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('写真を追加'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _PhotoPreviewGrid(
                      images: _pickedImages,
                      onRemove: _removeImageAt,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _pickedImages.isEmpty
                          ? '正面の写真があると見つけやすくなります'
                          : '1枚目をメイン写真として使います',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _CreateSectionCard(
                title: '場所と情報',
                child: Column(
                  children: <Widget>[
                    InkWell(
                      onTap: _fetchCurrentLocation,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: _isFetchingLocation
                                  ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Icon(
                                Icons.my_location_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text(
                                    '現在地を使う',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _addressLabel.isNotEmpty
                                        ? _addressLabel
                                        : '近くの位置を自動で入れます',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (_latitude != null && _longitude != null) ...<Widget>[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textHint,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textHint,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _memoController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: '目印メモ（例：駅の改札横、コンビニの前）',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'タグ',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags
                          .map(
                            (String tag) => FilterChip(
                          label: Text(tag),
                          selected: _selectedTags.contains(tag),
                          onSelected: (_) => _toggleTag(tag),
                        ),
                      )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _CreateSectionCard(
                title: 'ドリンクを追加',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextField(
                      controller: _drinkSearchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'ドリンク名で探す',
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_drinkSuggestions.isNotEmpty) ...<Widget>[
                      Text(
                        '候補',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._drinkSuggestions.map(
                            (String drink) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => _addDrink(drink),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.local_drink_rounded,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      drink,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.add_rounded),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '追加済み',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedDrinks.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'まだドリンクが追加されていません',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedDrinks
                            .map(
                              (String drink) => InputChip(
                            label: Text(drink),
                            onDeleted: () => _removeDrink(drink),
                            avatar: const Icon(
                              Icons.local_drink_rounded,
                              size: 18,
                            ),
                          ),
                        )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPreviewGrid extends StatelessWidget {
  const _PhotoPreviewGrid({
    required this.images,
    required this.onRemove,
  });

  final List<XFile> images;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Container(
        width: double.infinity,
        height: 132,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.photo_camera_back_rounded,
              size: 34,
              color: AppColors.primary,
            ),
            SizedBox(height: 8),
            Text(
              'まだ写真はありません',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final file = images[index];
          final isMain = index == 0;

          return Stack(
            children: <Widget>[
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  color: AppColors.surfaceSoft,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  File(file.path),
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isMain ? AppColors.accent : Colors.black54,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isMain ? 'メイン' : '写真 ${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onRemove(index),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CreateSectionCard extends StatelessWidget {
  const _CreateSectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}