import 'package:flutter/material.dart';

import '../models/vending_machine.dart';
import '../services/firestore_service.dart';

class MachineCreateScreen extends StatefulWidget {
  const MachineCreateScreen({super.key});

  @override
  State<MachineCreateScreen> createState() => _MachineCreateScreenState();
}

class _MachineCreateScreenState extends State<MachineCreateScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isSubmitting = false;

  double? _latitude;
  double? _longitude;

  // 🔥 12枠（最低構成）
  List<Map<String, dynamic>> _drinkSlots = List.generate(
    12,
        (_) => {
      'name': '',
      'manufacturer': null,
      'category': null,
      'isSoldOut': false,
    },
  );

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();

    if (name.isEmpty || _latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('必須項目を入力してください')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final machine = VendingMachine(
        id: '',
        name: name,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
        drinkSlots: _drinkSlots,
        imageUrl: null,
        tags: [],
        cashlessSupported: false,
        createdAt: null,
        updatedAt: null,
        lastCheckedAt: null,
        checkinCount: 0,
      );

      await FirestoreService.instance.createMachine(machine);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登録に失敗しました: $e')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Widget _buildBasicInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E7EB)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '自販機名（例：〇〇駅前）',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: '住所（任意）',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDummy() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('位置（仮）'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              // 🔥 MVP用ダミー（後でGPSに置き換え）
              setState(() {
                _latitude = 35.681236;
                _longitude = 139.767125;
              });
            },
            child: const Text('現在地をセット（仮）'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrinkEditorSimple() {
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
            'ドリンク（12枠）',
            style: TextStyle(
              fontFamily: 'Noto Sans JP',
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),

          ...List.generate(_drinkSlots.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'ドリンク ${index + 1}',
                ),
                onChanged: (value) {
                  _drinkSlots[index]['name'] = value;
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自販機登録'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(_isSubmitting ? '保存中...' : '登録する'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          _buildBasicInfo(),
          const SizedBox(height: 12),
          _buildLocationDummy(),
          const SizedBox(height: 12),
          _buildDrinkEditorSimple(),
        ],
      ),
    );
  }
}