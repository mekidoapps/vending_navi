abstract interface class ExternalMapService {
  Future<bool> openWalkingDirections({
    required double latitude,
    required double longitude,
  });
}
