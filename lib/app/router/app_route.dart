enum AppRoute {
  legacyRoot(name: 'legacyRoot', path: '/'),
  v2Foundation(name: 'v2Foundation', path: '/v2'),
  v2MachineDetail(name: 'v2MachineDetail', path: '/v2/machines/:machineId'),
  v2EmailAuth(name: 'v2EmailAuth', path: '/v2/auth/email'),
  v2MyPage(name: 'v2MyPage', path: '/v2/my');

  const AppRoute({required this.name, required this.path});

  final String name;
  final String path;
}
