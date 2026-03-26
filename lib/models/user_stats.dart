class UserStats {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final int checkinCount;
  final int machineCreatedCount;
  final int contributionScore;
  final int favoriteProductCount;
  final int favoriteMachineCount;
  final String? currentTitleId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserStats({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    this.checkinCount = 0,
    this.machineCreatedCount = 0,
    this.contributionScore = 0,
    this.favoriteProductCount = 0,
    this.favoriteMachineCount = 0,
    this.currentTitleId,
    this.createdAt,
    this.updatedAt,
  });

  int get favoriteTotalCount => favoriteProductCount + favoriteMachineCount;

  UserStats copyWith({
    String? userId,
    String? displayName,
    String? photoUrl,
    int? checkinCount,
    int? machineCreatedCount,
    int? contributionScore,
    int? favoriteProductCount,
    int? favoriteMachineCount,
    String? currentTitleId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserStats(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      checkinCount: checkinCount ?? this.checkinCount,
      machineCreatedCount: machineCreatedCount ?? this.machineCreatedCount,
      contributionScore: contributionScore ?? this.contributionScore,
      favoriteProductCount: favoriteProductCount ?? this.favoriteProductCount,
      favoriteMachineCount: favoriteMachineCount ?? this.favoriteMachineCount,
      currentTitleId: currentTitleId ?? this.currentTitleId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'display_name': displayName,
      'photo_url': photoUrl,
      'checkin_count': checkinCount,
      'machine_created_count': machineCreatedCount,
      'contribution_score': contributionScore,
      'favorite_product_count': favoriteProductCount,
      'favorite_machine_count': favoriteMachineCount,
      'current_title_id': currentTitleId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory UserStats.fromMap(String userId, Map<String, dynamic> map) {
    return UserStats(
      userId: userId,
      displayName: (map['display_name'] ?? 'ユーザー') as String,
      photoUrl: map['photo_url'] as String?,
      checkinCount: (map['checkin_count'] ?? 0) as int,
      machineCreatedCount: (map['machine_created_count'] ?? 0) as int,
      contributionScore: (map['contribution_score'] ?? 0) as int,
      favoriteProductCount: (map['favorite_product_count'] ?? 0) as int,
      favoriteMachineCount: (map['favorite_machine_count'] ?? 0) as int,
      currentTitleId: map['current_title_id'] as String?,
      createdAt: _toDateTime(map['created_at']),
      updatedAt: _toDateTime(map['updated_at']),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      return value.toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}