class MachineCreateResult {
  const MachineCreateResult({
    required this.machineId,
    required this.machineName,
    required this.expGained,
    required this.leveledUp,
  });

  final String machineId;
  final String machineName;
  final int expGained;
  final bool leveledUp;
}