enum AppRoute {
  legacyRoot(name: 'legacyRoot', path: '/'),
  v2Foundation(name: 'v2Foundation', path: '/v2'),
  v2MachineDetail(name: 'v2MachineDetail', path: '/v2/machines/:machineId');

  const AppRoute({required this.name, required this.path});

  final String name;
  final String path;
}
