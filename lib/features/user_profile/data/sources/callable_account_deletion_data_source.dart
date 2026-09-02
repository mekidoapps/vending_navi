import 'package:cloud_functions/cloud_functions.dart';

import 'account_deletion_data_source.dart';

final class CallableAccountDeletionDataSource
    implements AccountDeletionDataSource {
  CallableAccountDeletionDataSource(this._functions);

  static const String functionName = 'deleteAccount';

  static const String confirmation = 'DELETE_ACCOUNT';

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, Object?>> deleteAccount() async {
    final callable = _functions.httpsCallable(functionName);

    final response = await callable.call<Object?>(const <String, Object?>{
      'confirmation': confirmation,
    });

    final data = response.data;

    if (data is! Map) {
      throw const FormatException('deleteAccount response must be a map');
    }

    return data.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
}
