import 'package:flutter/material.dart';

import '../data/drink_master_data.dart';
import '../models/product.dart';

class DrinkPickerSheet extends StatefulWidget {
  const DrinkPickerSheet({
    super.key,
    this.initialManufacturer = 'すべて',
    this.initialQuery = '',
    this.title = 'ドリンクを選ぶ',
  });

  final String initialManufacturer;
  final String initialQuery;
  final String title;

  static Future<Product?> show(
      BuildContext context, {
        String initialManufacturer = 'すべて',
        String initialQuery = '',
        String title = 'ドリンクを選ぶ',
      }) {
    return showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DrinkPickerSheet(
          initialManufacturer: initialManufacturer,
          initialQuery: initialQuery,
          title: title,
        );
      },
    );
  }

  @override
  State<DrinkPickerSheet> createState() => _DrinkPickerSheetState();
}

class _DrinkPickerSheetState extends State<DrinkPickerSheet> {
  late final TextEditingController _searchController;

  late String _selectedManufacturer;
  late String _query;

  List<Product> get _products {
    return DrinkMasterData.search(
      query: _query,
      manufacturer: _selectedManufacturer,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedManufacturer = widget.initialManufacturer;
    _query = widget.initialQuery.trim();
    _searchController = TextEditingController(text: widget.initialQuery);
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() {
      _query = _searchController.text.trim();
    });
  }

  void _selectManufacturer(String manufacturer) {
    setState(() {
      _selectedManufacturer = manufacturer;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final products = _products;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'ドリンク名で検索',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                    onPressed: () {
                      _searchController.clear();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: DrinkMasterData.manufacturers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final manufacturer = DrinkMasterData.manufacturers[index];
                    final selected = manufacturer == _selectedManufacturer;

                    return ChoiceChip(
                      label: Text(manufacturer),
                      selected: selected,
                      onSelected: (_) => _selectManufacturer(manufacturer),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${products.length}件',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF60707A),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: products.isEmpty
                    ? const _DrinkPickerEmpty()
                    : ListView.separated(
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = products[index];

                    return _DrinkPickerRow(
                      product: product,
                      onTap: () => Navigator.of(context).pop(product),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrinkPickerRow extends StatelessWidget {
  const _DrinkPickerRow({
    required this.product,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FBFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE3E7EB),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_drink_rounded,
                  color: Color(0xFF3E7BFA),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.manufacturer} ・ ${product.category}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF60707A),
                      ),
                    ),
                    if (product.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: product.tags.take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFE3E7EB),
                              ),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF60707A),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrinkPickerEmpty extends StatelessWidget {
  const _DrinkPickerEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FBFC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE3E7EB)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 34),
            SizedBox(height: 10),
            Text(
              '一致するドリンクがありません',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334148),
              ),
            ),
            SizedBox(height: 6),
            Text(
              '検索語やメーカーを変えてみてください。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF60707A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}