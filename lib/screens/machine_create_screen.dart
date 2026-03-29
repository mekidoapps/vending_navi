import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vending_machine.dart';
import '../providers/auth_provider.dart';
import '../repositories/machine_repository.dart';
import '../services/location_service.dart';

class MachineCreateScreen extends StatefulWidget {
  const MachineCreateScreen({super.key});

  @override
  State<MachineCreateScreen> createState() => _MachineCreateScreenState();
}

class _MachineCreateScreenState extends State<MachineCreateScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _placeNoteController = TextEditingController();

  final MachineRepository _machineRepository = MachineRepository();
  final LocationService _locationService = LocationService();

  final Set<String> _paymentMethods = <String>{};
  final Set<String> _machineTags = <String>{};

  bool _isSaving = false;
  bool _isFetchingLocation = false;

  @override
  void dispose() {
    _nameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _placeNoteController.dispose();
    super.dispose();
  }

  // ✅ チップトグルを共通メソッドに統一
  void _toggle(Set<String> set, String value) {
    setState(() {
      set.contains(value) ? set.remove(value) : set.add(value);
    });
  }

  // ✅ 現在地を緯度経度フィールドに自動入力
  Future<void> _fillCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      final position = await _locationService.getCurrentPosition();

      if (!mounted) return;

      if (position == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('現在地を取得できませんでした'),
            action: SnackBarAction(
              label: '設定を開く',
              onPressed: () => _locationService.openAppSettings(),
            ),
          ),
        );
        return;
      }

      _latitudeController.text = position.latitude.toStringAsFixed(6);
      _longitudeController.text = position.longitude.toStringAsFixed(6);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('現在地を取得しました')),
      );
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    // ✅ AuthProvider経由でuserIdを取得
    final String? userId = context.read<AuthProvider>().currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final double latitude = double.parse(_latitudeController.text.trim());
      final double longitude = double.parse(_longitudeController.text.trim());

      final VendingMachine machine = VendingMachine(
        id: '',
        name: _nameController.text.trim(),
        latitude: latitude,
        longitude: longitude,
        geohash: '',
        placeNote: _placeNoteController.text.trim().isEmpty
            ? null
            : _placeNoteController.text.trim(),
        photoUrls: const <String>[],
        paymentMethods: _paymentMethods.toList(),
        machineTags: _machineTags.toList(),
        createdBy: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastVerifiedAt: DateTime.now(),
      );

      await _machineRepository.createMachine(machine);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('自販機を登録しました')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登録に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自販機を登録'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '自販機名',
                  hintText: '例: ○○駅南口横の自販機',
                ),
                validator: (String? value) {
                  if ((value ?? '').trim().isEmpty) {
                    return '自販機名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ✅ 現在地取得ボタン
              OutlinedButton.icon(
                onPressed: _isFetchingLocation ? null : _fillCurrentLocation,
                icon: _isFetchingLocation
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.my_location),
                label: Text(_isFetchingLocation ? '取得中…' : '現在地を使う'),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _latitudeController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '緯度',
                  hintText: '35.6812',
                ),
                validator: (String? value) {
                  final double? parsed =
                  double.tryParse((value ?? '').trim());
                  if (parsed == null) return '緯度を正しく入力してください';
                  if (parsed < -90 || parsed > 90) return '緯度の範囲が不正です';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _longitudeController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '経度',
                  hintText: '139.7671',
                ),
                validator: (String? value) {
                  final double? parsed =
                  double.tryParse((value ?? '').trim());
                  if (parsed == null) return '経度を正しく入力してください';
                  if (parsed < -180 || parsed > 180) return '経度の範囲が不正です';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _placeNoteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '場所メモ',
                  hintText: '例: 南口階段横 / ビル1F入口付近',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '支払い方法',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // ✅ _toggleで共通化
                  FilterChip(
                    label: const Text('現金'),
                    selected: _paymentMethods.contains('cash'),
                    onSelected: (_) => _toggle(_paymentMethods, 'cash'),
                  ),
                  FilterChip(
                    label: const Text('IC'),
                    selected: _paymentMethods.contains('ic'),
                    onSelected: (_) => _toggle(_paymentMethods, 'ic'),
                  ),
                  FilterChip(
                    label: const Text('PayPay'),
                    selected: _paymentMethods.contains('paypay'),
                    onSelected: (_) => _toggle(_paymentMethods, 'paypay'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '自販機タグ',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('屋内'),
                    selected: _machineTags.contains('indoor'),
                    onSelected: (_) => _toggle(_machineTags, 'indoor'),
                  ),
                  FilterChip(
                    label: const Text('屋外'),
                    selected: _machineTags.contains('outdoor'),
                    onSelected: (_) => _toggle(_machineTags, 'outdoor'),
                  ),
                  FilterChip(
                    label: const Text('立ち寄りやすい'),
                    selected: _machineTags.contains('easy_stop'),
                    onSelected: (_) => _toggle(_machineTags, 'easy_stop'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _isSaving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('登録する'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
