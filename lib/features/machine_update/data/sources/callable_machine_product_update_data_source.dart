import 'package:cloud_functions/cloud_functions.dart';

import 'machine_product_update_data_source.dart';

final class CallableMachineProductUpdateDataSource
    implements MachineProductUpdateDataSource {
  CallableMachineProductUpdateDataSource(this._functions);

  static const String functionName = 'updateVendingMachineProducts';

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, Object?>> updateVendingMachineProducts(
    Map<String, Object?> request,
  ) async {
    final callable = _functions.httpsCallable(functionName);
    final response = await callable.call<Object?>(request);
    final data = response.data;

    if (data is! Map) {
      throw const FormatException(
        'updateVendingMachineProducts response must be a map',
      );
    }

    return data.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
}
