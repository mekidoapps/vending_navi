import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/enums/app_enums.dart';
import '../models/product.dart';
import '../models/vending_machine_access.dart';
import '../providers/auth_provider.dart';
import '../providers/machine_provider.dart';
import '../repositories/machine_repository.dart';
import '../repositories/product_repository.dart';

class AddDrinkScreen extends StatefulWidget {
  final String machineId;
  final String machineName;

  const AddDrinkScreen({
    super.key,
    required this.machineId,
    required this.machineName,
  });

  @override
  State<AddDrinkScreen> createState() => _AddDrinkScreenState();
}

class _AddDrinkScreenState extends State<AddDrinkScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  List<Product> _products = <Product>[];
  Product? _selectedProduct;
  ItemTemperature _temperature = ItemTemperature.cold;
  bool _isLoading = false;
  bool _isSubmitting = false;

  final ProductRepository _productRepository = ProductRepository();
  final MachineRepository _machineRepository = MachineRepository();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts([String keyword = '']) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final List<Product> products = await _productRepository.fetchProducts(
        keyword: keyword.isEmpty ? null : keyword,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品を選択してください')),
      );
      return;
    }

    final String? userId = context.read<AuthProvider>().currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final DateTime now = DateTime.now();
      final String itemId = '${widget.machineId}_${_selectedProduct!.id}';
      final int? price = int.tryParse(_priceController.text.trim());

      final VendingMachineAccess item = VendingMachineAccess(
        id: itemId,
        machineId: widget.machineId,
        productId: _selectedProduct!.id,
        productNameSnapshot: _selectedProduct!.displayName,
        machineNameSnapshot: widget.machineName,
        price: price,
        temperature: _temperature,
        stockStatus: StockStatus.seenRecently,
        confidence: ConfidenceLevel.medium,
        lastSeenAt: now,
        lastReportType: 'user_add',
        createdAt: now,
        updatedAt: now,
      );

      await _machineRepository.saveMachineItem(item);

      if (!mounted) return;

      await context.read<MachineProvider>().refresh();

      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selectedProduct!.displayName} を追加しました')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ドリンクを追加'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSubmitting || _selectedProduct == null
                  ? null
                  : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('追加'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '商品名で検索（例: 綾鷹）',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _loadProducts,
            ),
          ),
          if (_selectedProduct != null) ...[
            _SelectedProductCard(
              product: _selectedProduct!,
              priceController: _priceController,
              temperature: _temperature,
              onTemperatureChanged: (ItemTemperature t) =>
                  setState(() => _temperature = t),
              onClear: () => setState(() => _selectedProduct = null),
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('商品が見つかりません'))
                    : ListView.builder(
                        itemCount: _products.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Product product = _products[index];
                          final bool isSelected =
                              _selectedProduct?.id == product.id;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : null,
                              child: const Icon(Icons.local_drink_outlined),
                            ),
                            title: Text(product.displayName),
                            subtitle: product.brandName.isNotEmpty
                                ? Text(product.brandName)
                                : null,
                            selected: isSelected,
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                            onTap: () =>
                                setState(() => _selectedProduct = product),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SelectedProductCard extends StatelessWidget {
  final Product product;
  final TextEditingController priceController;
  final ItemTemperature temperature;
  final ValueChanged<ItemTemperature> onTemperatureChanged;
  final VoidCallback onClear;

  const _SelectedProductCard({
    required this.product,
    required this.priceController,
    required this.temperature,
    required this.onTemperatureChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                    tooltip: '選択解除',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '価格（任意）',
                  prefixIcon: Icon(Icons.currency_yen),
                  hintText: '例: 140',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '温度',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('つめたい'),
                    selected: temperature == ItemTemperature.cold,
                    onSelected: (_) =>
                        onTemperatureChanged(ItemTemperature.cold),
                  ),
                  ChoiceChip(
                    label: const Text('あたたかい'),
                    selected: temperature == ItemTemperature.hot,
                    onSelected: (_) =>
                        onTemperatureChanged(ItemTemperature.hot),
                  ),
                  ChoiceChip(
                    label: const Text('冷/温'),
                    selected: temperature == ItemTemperature.both,
                    onSelected: (_) =>
                        onTemperatureChanged(ItemTemperature.both),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
