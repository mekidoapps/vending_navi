import 'package:cloud_functions/cloud_functions.dart';

import 'machine_registration_data_source.dart';

final class CallableMachineRegistrationDataSource
    implements MachineRegistrationDataSource {
  CallableMachineRegistrationDataSource(this._functions);

  static const String functionName = 'createVendingMachine';

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, Object?>> createVendingMachine(
    Map<String, Object?> request,
  ) async {
    final callable = _functions.httpsCallable(functionName);
    final response = await callable.call<Object?>(request);
    final data = response.data;

    if (data is! Map) {
      throw const FormatException(
        'createVendingMachine response must be a map',
      );
    }

    return data.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
}
