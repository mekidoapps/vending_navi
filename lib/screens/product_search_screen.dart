import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final TextEditingController controller = TextEditingController();

  List<Map<String, dynamic>> results = [];
  bool loading = false;

  Future<void> search() async {
    setState(() {
      loading = true;
    });

    final keyword = controller.text.trim();

    if (keyword.isEmpty) {
      setState(() {
        loading = false;
      });
      return;
    }

    final productQuery = await FirebaseFirestore.instance
        .collection('products')
        .where('name', isGreaterThanOrEqualTo: keyword)
        .get();

    List<Map<String, dynamic>> foundMachines = [];

    for (var product in productQuery.docs) {
      final productId = product.id;

      final machineItems = await FirebaseFirestore.instance
          .collection('machine_items')
          .where('product_id', isEqualTo: productId)
          .get();

      for (var item in machineItems.docs) {
        final machineId = item['machine_id'];

        final machineDoc = await FirebaseFirestore.instance
            .collection('machines')
            .doc(machineId)
            .get();

        if (machineDoc.exists) {
          foundMachines.add(machineDoc.data()!);
        }
      }
    }

    setState(() {
      results = foundMachines;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ドリンク検索'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: '綾鷹 / お〜いお茶 など',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: search,
                ),
              ],
            ),
          ),
          if (loading)
            const Center(child: CircularProgressIndicator()),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final machine = results[index];

                return ListTile(
                  title: Text(machine['name'] ?? '自販機'),
                  subtitle: Text(machine['place_note'] ?? ''),
                  leading: const Icon(Icons.local_drink),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}