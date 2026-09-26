import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/osm/presentation/osm_license_links.dart';
import 'package:vending_app/features/osm/presentation/v2_data_licenses_screen.dart';

void main() {
  testWidgets('OSM attributionとライセンス情報を表示する', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: V2DataLicensesScreen()));
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    expect(find.byKey(const Key('osmCopyrightLink')), findsOneWidget);
    expect(find.byKey(const Key('odblLicenseLink')), findsOneWidget);
    expect(find.textContaining('Google Maps'), findsOneWidget);
    expect(osmCopyrightUrl, 'https://www.openstreetmap.org/copyright');
    expect(odblLicenseUrl, 'https://opendatacommons.org/licenses/odbl/1-0/');
  });
}
