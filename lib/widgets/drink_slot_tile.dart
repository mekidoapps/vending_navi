import 'package:flutter/material.dart';
import '../models/drink_slot_data.dart';

class DrinkSlotTile extends StatelessWidget {
  const DrinkSlotTile({
    super.key,
    required this.slot,
    required this.onTap,
  });

  final DrinkSlotData slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasDrink = slot.name != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: hasDrink ? const Color(0xFFE8F4FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDrink
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFFE3E7EB),
          ),
        ),
        child: Center(
          child: Text(
            hasDrink ? slot.name! : '+',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: hasDrink ? 12 : 20,
              fontWeight: FontWeight.w700,
              color: hasDrink
                  ? const Color(0xFF334148)
                  : const Color(0xFF9AA5AD),
            ),
          ),
        ),
      ),
    );
  }
}