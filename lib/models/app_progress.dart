class AppProgress {
  const AppProgress({
    required this.exp,
    required this.level,
    required this.searchHistory,
    required this.viewedMachineIds,
    required this.viewedMachineNames,
    required this.createdMachineNames,
  });

  final int exp;
  final int level;
  final List<String> searchHistory;
  final List<String> viewedMachineIds;
  final List<String> viewedMachineNames;
  final List<String> createdMachineNames;

  factory AppProgress.initial() {
    return const AppProgress(
      exp: 0,
      level: 1,
      searchHistory: <String>[],
      viewedMachineIds: <String>[],
      viewedMachineNames: <String>[],
      createdMachineNames: <String>[],
    );
  }

  AppProgress copyWith({
    int? exp,
    int? level,
    List<String>? searchHistory,
    List<String>? viewedMachineIds,
    List<String>? viewedMachineNames,
    List<String>? createdMachineNames,
  }) {
    return AppProgress(
      exp: exp ?? this.exp,
      level: level ?? this.level,
      searchHistory: searchHistory ?? this.searchHistory,
      viewedMachineIds: viewedMachineIds ?? this.viewedMachineIds,
      viewedMachineNames: viewedMachineNames ?? this.viewedMachineNames,
      createdMachineNames: createdMachineNames ?? this.createdMachineNames,
    );
  }

  static int levelFromExp(int exp) {
    if (exp <= 0) return 1;
    return (exp ~/ 100) + 1;
  }

  int get expIntoCurrentLevel => exp % 100;

  int get expToNextLevel {
    final remain = 100 - expIntoCurrentLevel;
    return remain == 100 ? 0 : remain;
  }

  double get levelProgress {
    return (expIntoCurrentLevel / 100).clamp(0, 1);
  }
}