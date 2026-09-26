import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route.dart';

class V2OsmMachineSourceLabel extends StatelessWidget {
  const V2OsmMachineSourceLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const Key('osmMachineSourceLink'),
      onPressed: () => context.pushNamed(AppRoute.v2DataLicenses.name),
      icon: const Icon(Icons.info_outline, size: 16),
      label: const Text('位置データ: OpenStreetMap'),
    );
  }
}
