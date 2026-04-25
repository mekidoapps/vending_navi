enum FeedbackCategory {
  bug('bug', '不具合'),
  request('request', '要望'),
  usability('usability', '使いにくかった点'),
  other('other', 'その他');

  const FeedbackCategory(this.value, this.label);

  final String value;
  final String label;

  static FeedbackCategory fromValue(String value) {
    return FeedbackCategory.values.firstWhere(
          (e) => e.value == value,
      orElse: () => FeedbackCategory.other,
    );
  }
}