import 'package:flutter/material.dart';
import '../models/drink_slot.dart';

class DrinkGridPager extends StatelessWidget {
  const DrinkGridPager({
    super.key,
    required this.slots,
    required this.currentPage,
    required this.onTapSlot,
    required this.onPageChanged,
  });

  final List<DrinkSlot> slots;
  final int currentPage;
  final ValueChanged<DrinkSlot> onTapSlot;
  final ValueChanged<int> onPageChanged;

  static const int pageSize = 12;

  int get totalPages {
    final p = (slots.length / pageSize).ceil();
    return p == 0 ? 1 : p;
  }

  List<DrinkSlot> _pageSlots(int page) {
    final start = page * pageSize;
    final end = start + pageSize;
    if (start >= slots.length) return [];
    return slots.sublist(start, end > slots.length ? slots.length : end);
  }

  @override
  Widget build(BuildContext context) {
    final pageSlots = _pageSlots(currentPage);

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            itemCount: pageSize,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final globalIndex = currentPage * pageSize + index;
              final hasData = globalIndex < slots.length;
              final slot = hasData
                  ? slots[globalIndex]
                  : DrinkSlot.empty(
                page: currentPage,
                indexInPage: index,
              );

              return GestureDetector(
                onTap: () => onTapSlot(slot),
                child: Card(
                  child: Center(
                    child: hasData
                        ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          slot.name ?? '',
                          textAlign: TextAlign.center,
                        ),
                        if (slot.isSoldOut)
                          const Text(
                            '売切',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    )
                        : const Text('+'),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: currentPage > 0
                  ? () => onPageChanged(currentPage - 1)
                  : null,
              icon: const Icon(Icons.arrow_back),
            ),
            Text('${currentPage + 1} / $totalPages'),
            IconButton(
              onPressed: currentPage < totalPages - 1
                  ? () => onPageChanged(currentPage + 1)
                  : null,
              icon: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
      ],
    );
  }
}