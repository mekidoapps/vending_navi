import 'package:flutter/material.dart';

import '../../../app/theme/v2_spacing.dart';
import 'osm_license_links.dart';

class V2DataLicensesScreen extends StatelessWidget {
  const V2DataLicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('データ・ライセンス')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(V2Spacing.md),
          children: <Widget>[
            Text(
              'OpenStreetMap',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: V2Spacing.md),
            const Text('自販機位置データの一部にOpenStreetMapを使用しています。'),
            const SizedBox(height: V2Spacing.sm),
            const Text('© OpenStreetMap contributors'),
            const SizedBox(height: V2Spacing.sm),
            const Text(
              'OpenStreetMap data is available under the Open Database License (ODbL) 1.0.',
            ),
            const SizedBox(height: V2Spacing.md),
            ListTile(
              key: const Key('osmCopyrightLink'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.open_in_new),
              title: const Text('OpenStreetMap copyright'),
              onTap: () => openOsmLicenseLink(context, osmCopyrightUrl),
            ),
            ListTile(
              key: const Key('odblLicenseLink'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.open_in_new),
              title: const Text('ODbL 1.0'),
              onTap: () => openOsmLicenseLink(context, odblLicenseUrl),
            ),
            const SizedBox(height: V2Spacing.md),
            const Text(
              'ベース地図はGoogle Mapsが提供しています。OpenStreetMapは、'
              'ベース地図ではなく自販機位置の初期データの一部です。',
            ),
          ],
        ),
      ),
    );
  }
}
