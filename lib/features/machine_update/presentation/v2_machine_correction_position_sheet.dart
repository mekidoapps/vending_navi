import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../location/application/current_location_controller.dart';
import '../../vending_machine/domain/value_objects/geo_coordinate.dart';

class V2MachineCorrectionPositionSheet extends ConsumerStatefulWidget {
  const V2MachineCorrectionPositionSheet({
    super.key,
    required this.initialLocation,
  });

  final GeoCoordinate initialLocation;

  static Future<GeoCoordinate?> show(
    BuildContext context, {
    required GeoCoordinate initialLocation,
  }) {
    return showModalBottomSheet<GeoCoordinate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          V2MachineCorrectionPositionSheet(initialLocation: initialLocation),
    );
  }

  @override
  ConsumerState<V2MachineCorrectionPositionSheet> createState() =>
      _V2MachineCorrectionPositionSheetState();
}

class _V2MachineCorrectionPositionSheetState
    extends ConsumerState<V2MachineCorrectionPositionSheet> {
  static const double _initialZoom = 17;

  GoogleMapController? _mapController;
  LatLng? _pendingTarget;
  late GeoCoordinate _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = LatLng(
      widget.initialLocation.latitude,
      widget.initialLocation.longitude,
    );

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              V2Spacing.md,
              V2Spacing.sm,
              V2Spacing.sm,
              V2Spacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '位置を修正',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '閉じる',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                GoogleMap(
                  key: const Key('machineCorrectionPositionMap'),
                  initialCameraPosition: CameraPosition(
                    target: initialTarget,
                    zoom: _initialZoom,
                  ),
                  myLocationEnabled: ref
                      .watch(currentLocationControllerProvider)
                      .hasLocation,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onCameraMove: (position) {
                    _pendingTarget = position.target;
                  },
                  onCameraIdle: _commitPendingTarget,
                ),
                IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: const Icon(
                        Icons.location_pin,
                        key: Key('machineCorrectionFixedCenterPin'),
                        size: 46,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: V2Spacing.md,
                  right: V2Spacing.md,
                  top: V2Spacing.md,
                  child: Material(
                    elevation: 1,
                    borderRadius: V2Radius.card,
                    color: Theme.of(context).colorScheme.surface,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: V2Spacing.md,
                        vertical: V2Spacing.sm,
                      ),
                      child: Text(
                        '地図を動かして、正しい自販機の位置にピンを合わせてください。',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: V2Spacing.md,
                  bottom: V2Spacing.md,
                  child: FloatingActionButton.small(
                    key: const Key('machineCorrectionRecenterButton'),
                    heroTag: 'machineCorrectionRecenterButton',
                    tooltip: '現在地へ移動',
                    onPressed: _recenter,
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              V2Spacing.lg,
              V2Spacing.md,
              V2Spacing.lg,
              V2Spacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '選択位置: '
                  '${_selectedLocation.latitude.toStringAsFixed(5)}, '
                  '${_selectedLocation.longitude.toStringAsFixed(5)}',
                  key: const Key('machineCorrectionPositionStatus'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: V2Spacing.sm),
                FilledButton.icon(
                  key: const Key('machineCorrectionPositionConfirmButton'),
                  onPressed: _confirm,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('この位置を提案'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _commitPendingTarget() {
    final target = _pendingTarget;
    if (target == null) {
      return;
    }

    setState(() {
      _selectedLocation = GeoCoordinate(
        latitude: target.latitude,
        longitude: target.longitude,
      );
      _pendingTarget = null;
    });
  }

  Future<void> _recenter() async {
    var locationState = ref.read(currentLocationControllerProvider);

    if (locationState.location == null) {
      await ref.read(currentLocationControllerProvider.notifier).locate();
      locationState = ref.read(currentLocationControllerProvider);
    }

    if (!mounted) {
      return;
    }

    final location = locationState.location;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('現在地を取得できませんでした。地図を動かして選択できます。')),
      );
      return;
    }

    final target = LatLng(location.latitude, location.longitude);

    setState(() {
      _selectedLocation = GeoCoordinate(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      _pendingTarget = null;
    });

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, _initialZoom),
    );
  }

  void _confirm() {
    _commitPendingTarget();
    Navigator.of(context).pop(_selectedLocation);
  }
}
