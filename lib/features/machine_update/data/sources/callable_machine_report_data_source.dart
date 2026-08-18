import 'package:cloud_functions/cloud_functions.dart';

import 'machine_report_data_source.dart';

final class CallableMachineReportDataSource implements MachineReportDataSource {
  CallableMachineReportDataSource(this._functions);

  static const String functionName = 'submitMachineReport';

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, Object?>> submitMachineReport(
    Map<String, Object?> request,
  ) async {
    final callable = _functions.httpsCallable(functionName);
    final response = await callable.call<Object?>(request);
    final data = response.data;

    if (data is! Map) {
      throw const FormatException('submitMachineReport response must be a map');
    }

    return data.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
}
