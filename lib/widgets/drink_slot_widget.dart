import 'package:flutter/material.dart';

import '../models/drink_slot.dart';

class DrinkSlotWidget extends StatelessWidget {
  const DrinkSlotWidget({
    super.key,
    required this.slot,
    required this.isSelected,
    required this.isEditable,
    required this.onTap,
  });

  final DrinkSlot slot;
  final bool isSelected;
  final bool isEditable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFFE3E7EB);

    final backgroundColor = slot.isEmpty
        ? const Color(0xFFF6F8F9)
        : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? const <BoxShadow>[
            BoxShadow(
              color: Color(0x1439A89C),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: slot.isEmpty
                  ? _EmptySlotBody(isEditable: isEditable)
                  : _FilledSlotBody(slot: slot),
            ),
            if (slot.isSoldOut && !slot.isEmpty)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.28),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '売切',
                        style: TextStyle(
                          fontFamily: 'Noto Sans JP',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptySlotBody extends StatelessWidget {
  const _EmptySlotBody({required this.isEditable});

  final bool isEditable;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            isEditable ? Icons.add_rounded : Icons.remove_rounded,
            size: 24,
            color: const Color(0xFF7A8791),
          ),
          const SizedBox(height: 6),
          Text(
            isEditable ? '＋追加' : '未登録',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Noto Sans JP',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A8791),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilledSlotBody extends StatelessWidget {
  const _FilledSlotBody({required this.slot});

  final DrinkSlot slot;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          slot.manufacturer?.trim().isNotEmpty == true
              ? slot.manufacturer!
              : 'メーカー未設定',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Noto Sans JP',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF60707A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          slot.name?.trim().isNotEmpty == true ? slot.name! : '商品未設定',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Noto Sans JP',
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2A30),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          slot.category?.trim().isNotEmpty == true ? slot.category! : '種類未設定',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Noto Sans JP',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7A8791),
          ),
        ),
      ],
    );
  }
}