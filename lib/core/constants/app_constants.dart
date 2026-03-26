class AppConstants {
  AppConstants._();

  static const String appName = 'Vending Navi';

  static const double defaultLatitude = 35.681236;
  static const double defaultLongitude = 139.767125;
  static const double defaultMapZoom = 15.0;

  static const int maxMachinePhotos = 5;
  static const int maxCheckinPhotos = 3;
  static const int maxCommentLength = 120;

  static const Duration locationTimeout = Duration(seconds: 10);
  static const Duration snackBarDuration = Duration(seconds: 2);

  static const double nearbySearchRadiusKm = 3.0;
  static const int recentSeenDays = 7;
  static const int mediumSeenDays = 30;

  static const List<String> defaultProductCategories = <String>[
    'tea',
    'water',
    'coffee',
    'black_tea',
    'soda',
    'juice',
    'sports_drink',
    'energy_drink',
    'milk_beverage',
    'soup',
    'other',
  ];

  static const List<String> defaultMachineTags = <String>[
    'indoor',
    'outdoor',
    'easy_stop',
    'station_near',
    'office_area',
    '24h_area',
  ];

  static const List<String> defaultPaymentMethods = <String>[
    'cash',
    'ic',
    'paypay',
    'credit_card',
    'unknown',
  ];
}