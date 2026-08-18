enum MachineReportCategory {
  machineRemoved,
  duplicate,
  inaccessible,
  inappropriatePhoto,
  inappropriateText,
  other;

  String get wireValue => switch (this) {
    MachineReportCategory.machineRemoved => 'machineRemoved',
    MachineReportCategory.duplicate => 'duplicate',
    MachineReportCategory.inaccessible => 'inaccessible',
    MachineReportCategory.inappropriatePhoto => 'inappropriatePhoto',
    MachineReportCategory.inappropriateText => 'inappropriateText',
    MachineReportCategory.other => 'other',
  };
}
