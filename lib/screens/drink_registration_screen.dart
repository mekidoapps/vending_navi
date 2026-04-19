import 'package:flutter/material.dart';
import '../models/drink_slot_data.dart';

class DrinkRegistrationScreen extends StatefulWidget {
  const DrinkRegistrationScreen({
    super.key,
    required this.initialSlots,
  });

  final List<DrinkSlotData> initialSlots;

  @override
  State<DrinkRegistrationScreen> createState() =>
      _DrinkRegistrationScreenState();
}

class _DrinkRegistrationScreenState
    extends State<DrinkRegistrationScreen> {
  late List<DrinkSlotData> slots;

  @override
  void initState() {
    super.initState();
    slots = List.from(widget.initialSlots);
  }

  void _updateName(int index, String value) {
    setState(() {
      slots[index] = slots[index].copyWith(name: value);
    });
  }

  void _toggleSoldOut(int index) {
    setState(() {
      final current = slots[index];
      slots[index] = current.copyWith(
        isSoldOut: !current.isSoldOut,
      );
    });
  }

  void _save() {
    Navigator.pop(context, slots);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ドリンク登録'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          )
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.8,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: slots.length,
        itemBuilder: (_, i) {
          final slot = slots[i];

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  TextField(
                    decoration:
                    const InputDecoration(hintText: 'ドリンク名'),
                    controller:
                    TextEditingController(text: slot.name ?? ''),
                    onChanged: (v) => _updateName(i, v),
                  ),
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('売切'),
                      Switch(
                        value: slot.isSoldOut,
                        onChanged: (_) => _toggleSoldOut(i),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}