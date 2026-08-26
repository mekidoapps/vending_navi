import 'dart:convert';
import 'dart:io';

import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';

const _outputPath = 'functions/fixtures/master_fixture.json';

void main(List<String> arguments) {
  final checkOnly = arguments.contains('--check');

  final fixture = <String, Object>{
    'schemaVersion': 1,
    'manufacturers': [
      for (final manufacturer in ProductMasterFixture.manufacturers)
        <String, Object>{
          'id': manufacturer.id.value,
          'name': manufacturer.name,
          'displayShortName': manufacturer.displayShortName,
          'searchKeywords': manufacturer.searchKeywords,
          'presetProductIds': [
            for (final productId in manufacturer.presetProductIds)
              productId.value,
          ],
          'isActive': manufacturer.isActive,
          'createdAt': manufacturer.createdAt.toUtc().toIso8601String(),
          'updatedAt': manufacturer.updatedAt.toUtc().toIso8601String(),
        },
    ],
    'products': [
      for (final product in ProductMasterFixture.products)
        <String, Object>{
          'id': product.id.value,
          'name': product.name,
          'manufacturerId': product.manufacturerId.value,
          'searchKeywords': product.searchKeywords,
          'genreIds': [for (final genre in product.genres) genre.id],
          'isActive': product.isActive,
          'createdAt': product.createdAt.toUtc().toIso8601String(),
          'updatedAt': product.updatedAt.toUtc().toIso8601String(),
        },
    ],
  };

  final generated = '${const JsonEncoder.withIndent('  ').convert(fixture)}\n';
  final output = File(_outputPath);

  if (checkOnly) {
    if (!output.existsSync()) {
      stderr.writeln(
        'MASTER_FIXTURE_CHECK_FAILED: $_outputPath does not exist.',
      );
      exitCode = 1;
      return;
    }

    final current = output.readAsStringSync().replaceAll('\r\n', '\n');

    if (current != generated) {
      stderr.writeln(
        'MASTER_FIXTURE_CHECK_FAILED: '
        'functions fixture differs from ProductMasterFixture.',
      );
      exitCode = 1;
      return;
    }

    stdout.writeln(
      'MASTER_FIXTURE_CHECK_OK '
      'manufacturers=${ProductMasterFixture.manufacturers.length} '
      'products=${ProductMasterFixture.products.length}',
    );
    return;
  }

  output.writeAsStringSync(generated);

  stdout.writeln(
    'MASTER_FIXTURE_EXPORT_OK '
    'manufacturers=${ProductMasterFixture.manufacturers.length} '
    'products=${ProductMasterFixture.products.length} '
    'path=$_outputPath',
  );
}
