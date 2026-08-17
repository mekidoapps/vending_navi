import 'package:cloud_functions/cloud_functions.dart';

import 'machine_photo_finalization_data_source.dart';

final class CallableMachinePhotoFinalizationDataSource
    implements MachinePhotoFinalizationDataSource {
  CallableMachinePhotoFinalizationDataSource(this._functions);

  static const String functionName = 'addVendingMachinePhoto';

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, Object?>> addVendingMachinePhoto(
    Map<String, Object?> request,
  ) async {
    final callable = _functions.httpsCallable(functionName);
    final response = await callable.call<Object?>(request);
    final data = response.data;

    if (data is! Map) {
      throw const FormatException(
        'addVendingMachinePhoto response must be a map',
      );
    }

    return data.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
}
