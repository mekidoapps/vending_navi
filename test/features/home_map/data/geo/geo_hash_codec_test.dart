import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/home_map/data/geo/geo_hash_codec.dart';

void main() {
  test('東京駅付近を既知のgeohashへ変換する', () {
    final geohash = GeoHashCodec.encode(
      latitude: 35.681236,
      longitude: 139.767125,
      precision: 6,
    );

    expect(geohash, 'xn76ur');
  });

  test('不正座標を拒否する', () {
    expect(
      () => GeoHashCodec.encode(latitude: 91, longitude: 139, precision: 6),
      throwsFormatException,
    );
  });
}
