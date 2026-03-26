import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/vending_machine.dart';
import '../repositories/machine_repository.dart';

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

  final Set<String> _paymentMethods = <String>{};
  final Set<String> _machineTags = <String>{};

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _placeNoteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

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
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildToggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _latitudeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '緯度',
                  hintText: '35.6812',
                ),
                validator: (String? value) {
                  final double? parsed = double.tryParse((value ?? '').trim());
                  if (parsed == null) {
                    return '緯度を正しく入力してください';
                  }
                  if (parsed < -90 || parsed > 90) {
                    return '緯度の範囲が不正です';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _longitudeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '経度',
                  hintText: '139.7671',
                ),
                validator: (String? value) {
                  final double? parsed = double.tryParse((value ?? '').trim());
                  if (parsed == null) {
                    return '経度を正しく入力してください';
                  }
                  if (parsed < -180 || parsed > 180) {
                    return '経度の範囲が不正です';
                  }
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
                  _buildToggleChip(
                    label: '現金',
                    selected: _paymentMethods.contains('cash'),
                    onTap: () {
                      setState(() {
                        _paymentMethods.contains('cash')
                            ? _paymentMethods.remove('cash')
                            : _paymentMethods.add('cash');
                      });
                    },
                  ),
                  _buildToggleChip(
                    label: 'IC',
                    selected: _paymentMethods.contains('ic'),
                    onTap: () {
                      setState(() {
                        _paymentMethods.contains('ic')
                            ? _paymentMethods.remove('ic')
                            : _paymentMethods.add('ic');
                      });
                    },
                  ),
                  _buildToggleChip(
                    label: 'PayPay',
                    selected: _paymentMethods.contains('paypay'),
                    onTap: () {
                      setState(() {
                        _paymentMethods.contains('paypay')
                            ? _paymentMethods.remove('paypay')
                            : _paymentMethods.add('paypay');
                      });
                    },
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
                  _buildToggleChip(
                    label: '屋内',
                    selected: _machineTags.contains('indoor'),
                    onTap: () {
                      setState(() {
                        _machineTags.contains('indoor')
                            ? _machineTags.remove('indoor')
                            : _machineTags.add('indoor');
                      });
                    },
                  ),
                  _buildToggleChip(
                    label: '屋外',
                    selected: _machineTags.contains('outdoor'),
                    onTap: () {
                      setState(() {
                        _machineTags.contains('outdoor')
                            ? _machineTags.remove('outdoor')
                            : _machineTags.add('outdoor');
                      });
                    },
                  ),
                  _buildToggleChip(
                    label: '立ち寄りやすい',
                    selected: _machineTags.contains('easy_stop'),
                    onTap: () {
                      setState(() {
                        _machineTags.contains('easy_stop')
                            ? _machineTags.remove('easy_stop')
                            : _machineTags.add('easy_stop');
                      });
                    },
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