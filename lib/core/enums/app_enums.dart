enum MachineStatus {
  active,
  hidden,
  archived,
}

enum ProductStatus {
  active,
  tentative,
  archived,
}

enum ProductCategory {
  tea,
  water,
  coffee,
  blackTea,
  soda,
  juice,
  sportsDrink,
  energyDrink,
  milkBeverage,
  soup,
  other,
}

enum ItemTemperature {
  cold,
  hot,
  both,
  unknown,
}

enum StockStatus {
  seenRecently,
  maybeAvailable,
  soldOutReported,
  unknown,
}

enum ConfidenceLevel {
  high,
  medium,
  low,
}

enum FavoriteTargetType {
  product,
  machine,
}

enum CheckinActionType {
  visit,
  found,
  soldOut,
  priceUpdate,
  photoUpdate,
  machineCreate,
}

enum SearchSortType {
  nearest,
  latest,
  cheapest,
  bestMatch,
}