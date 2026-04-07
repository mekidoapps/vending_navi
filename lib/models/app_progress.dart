class AppProgress {
  const AppProgress({
    required this.level,
    required this.exp,
    required this.searchHistory,
    required this.viewedMachineNames,
    required this.createdMachineNames,
  });

  final int level;
  final int exp;
  final List<String> searchHistory;
  final List<String> viewedMachineNames;
  final List<String> createdMachineNames;

  factory AppProgress.initial() {
    return const AppProgress(
      level: 1,
      exp: 0,
      searchHistory: <String>[],
      viewedMachineNames: <String>[],
      createdMachineNames: <String>[],
    );
  }

  factory AppProgress.fromJson(Map<String, dynamic> json) {
    return AppProgress(
      level: _readInt(json['level'], fallback: 1),
      exp: _readInt(json['exp'], fallback: 0),
      searchHistory: _readStringList(json['searchHistory']),
      viewedMachineNames: _readStringList(json['viewedMachineNames']),
      createdMachineNames: _readStringList(json['createdMachineNames']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'level': level,
      'exp': exp,
      'searchHistory': searchHistory,
      'viewedMachineNames': viewedMachineNames,
      'createdMachineNames': createdMachineNames,
    };
  }

  AppProgress copyWith({
    int? level,
    int? exp,
    List<String>? searchHistory,
    List<String>? viewedMachineNames,
    List<String>? createdMachineNames,
  }) {
    return AppProgress(
      level: level ?? this.level,
      exp: exp ?? this.exp,
      searchHistory: searchHistory ?? this.searchHistory,
      viewedMachineNames: viewedMachineNames ?? this.viewedMachineNames,
      createdMachineNames: createdMachineNames ?? this.createdMachineNames,
    );
  }

  double get levelProgress {
    final currentLevelBase = (level - 1) * 100;
    final nextLevelBase = level * 100;
    final span = nextLevelBase - currentLevelBase;

    if (span <= 0) return 0;

    final raw = (exp - currentLevelBase) / span;
    if (raw < 0) return 0;
    if (raw > 1) return 1;
    return raw;
  }

  int get expToNextLevel {
    final nextLevelBase = level * 100;
    final remain = nextLevelBase - exp;
    return remain < 0 ? 0 : remain;
  }

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return fallback;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return <String>[];
  }
}