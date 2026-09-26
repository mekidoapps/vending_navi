import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/osm_map_controller.dart';
import '../data/osm_map_repository.dart';
import 'v2_osm_machine_source_label.dart';

/// Read-only OSM detail. Native product/photo/update flows are not available.
class V2OsmMachineDetailScreen extends ConsumerStatefulWidget {
  const V2OsmMachineDetailScreen({required this.sourceId, super.key});

  final String sourceId;

  @override
  ConsumerState<V2OsmMachineDetailScreen> createState() =>
      _V2OsmMachineDetailScreenState();
}

class _V2OsmMachineDetailScreenState
    extends ConsumerState<V2OsmMachineDetailScreen> {
  late final Future<OsmMapPoint?> _point;

  @override
  void initState() {
    super.initState();
    _point = ref.read(osmMapRepositoryProvider).getPoint(widget.sourceId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自販機の位置情報')),
      body: FutureBuilder<OsmMapPoint?>(
        future: _point,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('位置情報を確認できませんでした'));
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final point = snapshot.data;
          if (point == null) {
            return const Center(child: Text('位置情報がありません'));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                point.brand ?? point.operator ?? '飲料自販機（OSM位置情報）',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (point.brand != null && point.operator != null)
                Text('運営者: ${point.operator}'),
              Text('位置: ${point.latitude}, ${point.longitude}'),
              const SizedBox(height: 12),
              const Text('商品情報: 不明'),
              const Text('写真: なし'),
              const V2OsmMachineSourceLabel(),
            ],
          );
        },
      ),
    );
  }
}
