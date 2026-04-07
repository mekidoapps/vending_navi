class FreshnessLevel {
  const FreshnessLevel._(this.label);

  final String label;

  static const veryFresh = FreshnessLevel._('veryFresh');
  static const fresh = FreshnessLevel._('fresh');
  static const normal = FreshnessLevel._('normal');
  static const old = FreshnessLevel._('old');
  static const unknown = FreshnessLevel._('unknown');
}

class FreshnessUtil {
  static FreshnessLevel getLevel(DateTime? dateTime) {
    if (dateTime == null) return FreshnessLevel.unknown;

    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inHours <= 6) {
      return FreshnessLevel.veryFresh;
    } else if (diff.inHours <= 24) {
      return FreshnessLevel.fresh;
    } else if (diff.inDays <= 3) {
      return FreshnessLevel.normal;
    } else {
      return FreshnessLevel.old;
    }
  }

  static String getLabel(FreshnessLevel level) {
    if (level == FreshnessLevel.veryFresh) return 'さっき更新';
    if (level == FreshnessLevel.fresh) return '今日更新';
    if (level == FreshnessLevel.normal) return '最近更新';
    if (level == FreshnessLevel.old) return '情報古め';
    return '未更新';
  }
}