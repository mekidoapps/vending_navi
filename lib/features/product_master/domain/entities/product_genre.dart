enum ProductGenre {
  tea(id: 'tea', label: 'お茶'),
  greenTea(id: 'green_tea', label: '緑茶'),
  coffee(id: 'coffee', label: 'コーヒー'),
  water(id: 'water', label: '水'),
  carbonated(id: 'carbonated', label: '炭酸飲料'),
  juice(id: 'juice', label: 'ジュース'),
  sportsDrink(id: 'sports_drink', label: 'スポーツドリンク'),
  energyDrink(id: 'energy_drink', label: 'エナジードリンク'),
  other(id: 'other', label: 'その他');

  const ProductGenre({required this.id, required this.label});

  final String id;
  final String label;

  static ProductGenre? tryFromId(String value) {
    for (final genre in values) {
      if (genre.id == value) {
        return genre;
      }
    }
    return null;
  }
}
