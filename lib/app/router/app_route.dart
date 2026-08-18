enum AppRoute {
  legacyRoot(name: 'legacyRoot', path: '/'),
  v2Foundation(name: 'v2Foundation', path: '/v2'),
  v2MachineDetail(name: 'v2MachineDetail', path: '/v2/machines/:machineId'),
  v2MachineUpdateMenu(
    name: 'v2MachineUpdateMenu',
    path: '/v2/machines/:machineId/update',
  ),
  v2PhotoProductUpdate(
    name: 'v2PhotoProductUpdate',
    path: '/v2/machines/:machineId/update/photo',
  ),
  v2PhotoProductUpdateConfirmation(
    name: 'v2PhotoProductUpdateConfirmation',
    path: '/v2/machines/:machineId/update/photo/confirm',
  ),
  v2ManualProductUpdate(
    name: 'v2ManualProductUpdate',
    path: '/v2/machines/:machineId/update/products',
  ),
  v2ProductUpdateConfirmation(
    name: 'v2ProductUpdateConfirmation',
    path: '/v2/machines/:machineId/update/products/confirm',
  ),
  v2MachineCorrection(
    name: 'v2MachineCorrection',
    path: '/v2/machines/:machineId/update/basic',
  ),
  v2MachineCorrectionConfirmation(
    name: 'v2MachineCorrectionConfirmation',
    path: '/v2/machines/:machineId/update/basic/confirm',
  ),
  v2MachineReport(
    name: 'v2MachineReport',
    path: '/v2/machines/:machineId/update/report',
  ),
  v2MachineReportConfirmation(
    name: 'v2MachineReportConfirmation',
    path: '/v2/machines/:machineId/update/report/confirm',
  ),
  v2EmailAuth(name: 'v2EmailAuth', path: '/v2/auth/email'),
  v2MyPage(name: 'v2MyPage', path: '/v2/my'),
  v2RegistrationPosition(
    name: 'v2RegistrationPosition',
    path: '/v2/register/position',
  ),
  v2RegistrationDuplicates(
    name: 'v2RegistrationDuplicates',
    path: '/v2/register/duplicates',
  ),
  v2RegistrationMethod(
    name: 'v2RegistrationMethod',
    path: '/v2/register/method',
  ),
  v2RegistrationPhoto(name: 'v2RegistrationPhoto', path: '/v2/register/photo'),
  v2RegistrationPhotoCandidates(
    name: 'v2RegistrationPhotoCandidates',
    path: '/v2/register/photo/candidates',
  ),
  v2RegistrationManufacturer(
    name: 'v2RegistrationManufacturer',
    path: '/v2/register/manufacturer',
  ),
  v2RegistrationConfirmation(
    name: 'v2RegistrationConfirmation',
    path: '/v2/register/confirm',
  );

  const AppRoute({required this.name, required this.path});

  final String name;
  final String path;
}
