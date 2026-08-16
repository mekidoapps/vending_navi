import 'package:cloud_functions/cloud_functions.dart';

import 'photo_recognition_data_source.dart';

final class CallablePhotoRecognitionDataSource
    implements PhotoRecognitionDataSource {
  CallablePhotoRecognitionDataSource(this._functions);

  static const String functionName = 'recognizeVendingMachinePhoto';

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, Object?>> recognize({
    required String recognitionRequestId,
    required String uploadId,
  }) async {
    final callable = _functions.httpsCallable(functionName);
    final response = await callable.call<Object?>(<String, Object?>{
      'recognitionRequestId': recognitionRequestId,
      'uploadId': uploadId,
    });

    final data = response.data;
    if (data is! Map) {
      throw const FormatException(
        'recognizeVendingMachinePhoto response must be a map',
      );
    }

    return data.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
}
