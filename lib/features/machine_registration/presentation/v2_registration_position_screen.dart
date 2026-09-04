import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../location/application/current_location_controller.dart';
import '../../location/application/current_location_state.dart';
import '../../location/domain/entities/current_location.dart';
import '../../vending_machine/domain/value_objects/geo_coordinate.dart';
import '../application/machine_registration_controller.dart';
import 'v2_registration_home_action.dart';

typedef V2RegistrationPositionMapBuilder =
    Widget Function(
      BuildContext context,
      LatLng initialTarget,
      ValueChanged<LatLng> onCameraMove,
      VoidCallback onCameraIdle,
    );

class V2RegistrationPositionScreen extends ConsumerStatefulWidget {
  const V2RegistrationPositionScreen({
    super.key,
    this.mapBuilder,
    this.autoLocate = true,
    this.onContinue,
  });

  /// Test/preview seam. Production renders GoogleMap.
  final V2RegistrationPositionMapBuilder? mapBuilder;
  final bool autoLocate;

  /// Phase 6 flow seam. P6-05 connects this to duplicate-candidate handling.
  final VoidCallback? onContinue;

  @override
  ConsumerState<V2RegistrationPositionScreen> createState() =>
      _V2RegistrationPositionScreenState();
}

class _V2RegistrationPositionScreenState
    extends ConsumerState<V2RegistrationPositionScreen> {
  static const LatLng _fallbackTarget = LatLng(36.2048, 138.2529);
  static const double _initialZoom = 17;

  GoogleMapController? _mapController;
  LatLng? _pendingTarget;
  bool _seededFromCurrentLocation = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final draft = ref.read(machineRegistrationControllerProvider).draft;
      if (draft.location != null) {
        return;
      }

      final currentLocation = ref
          .read(currentLocationControllerProvider)
          .location;
      if (currentLocation != null) {
        _seededFromCurrentLocation = true;
        _setSelectedLocation(
          LatLng(currentLocation.latitude, currentLocation.longitude),
          moveCamera: true,
        );
        return;
      }

      if (widget.autoLocate) {
        ref.read(currentLocationControllerProvider.notifier).locate();
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registrationState = ref.watch(machineRegistrationControllerProvider);
    final currentLocationState = ref.watch(currentLocationControllerProvider);
    final draftLocation = registrationState.draft.location;

    ref.listen<CurrentLocationState>(currentLocationControllerProvider, (
      previous,
      next,
    ) {
      final location = next.location;
      if (location == null ||
          _seededFromCurrentLocation ||
          ref.read(machineRegistrationControllerProvider).draft.location !=
              null) {
        return;
      }

      _seededFromCurrentLocation = true;
      _setSelectedLocation(
        LatLng(location.latitude, location.longitude),
        moveCamera: true,
      );
    });

    final initialTarget = _initialTarget(
      draftLocation: draftLocation,
      currentLocation: currentLocationState.location,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('自販機の位置'),
        actions: V2RegistrationHomeAction.appBarActions(context, ref),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _buildMap(initialTarget),
                  const IgnorePointer(child: _FixedCenterPin()),
                  const Positioned(
                    left: V2Spacing.md,
                    right: V2Spacing.md,
                    top: V2Spacing.md,
                    child: _PositionGuideCard(),
                  ),
                  Positioned(
                    right: V2Spacing.md,
                    bottom: V2Spacing.md,
                    child: FloatingActionButton.small(
                      key: const Key('registrationRecenterButton'),
                      heroTag: 'registrationRecenterButton',
                      onPressed: _recenter,
                      tooltip: '現在地へ戻る',
                      child: const Icon(Icons.my_location_rounded),
                    ),
                  ),
                ],
              ),
            ),
            _BottomActions(
              hasSelectedLocation: draftLocation != null,
              location: draftLocation,
              onContinue: _continue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(LatLng initialTarget) {
    final overrideBuilder = widget.mapBuilder;
    if (overrideBuilder != null) {
      return overrideBuilder(
        context,
        initialTarget,
        _onCameraMove,
        _onCameraIdle,
      );
    }

    return GoogleMap(
      key: const Key('registrationPositionGoogleMap'),
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
        _onCameraMove(position.target);
      },
      onCameraIdle: _onCameraIdle,
    );
  }

  LatLng _initialTarget({
    required GeoCoordinate? draftLocation,
    required CurrentLocation? currentLocation,
  }) {
    if (draftLocation != null) {
      return LatLng(draftLocation.latitude, draftLocation.longitude);
    }
    if (currentLocation != null) {
      return LatLng(currentLocation.latitude, currentLocation.longitude);
    }
    return _fallbackTarget;
  }

  void _onCameraMove(LatLng target) {
    _pendingTarget = target;
  }

  void _onCameraIdle() {
    final target = _pendingTarget;
    if (target == null) {
      return;
    }

    _setSelectedLocation(target);
    _pendingTarget = null;
  }

  void _setSelectedLocation(LatLng target, {bool moveCamera = false}) {
    ref
        .read(machineRegistrationControllerProvider.notifier)
        .setLocation(
          GeoCoordinate(latitude: target.latitude, longitude: target.longitude),
        );

    if (moveCamera) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, _initialZoom),
      );
    }
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
        const SnackBar(content: Text('現在地を取得できませんでした。地図を動かして位置を選べます。')),
      );
      return;
    }

    _setSelectedLocation(
      LatLng(location.latitude, location.longitude),
      moveCamera: true,
    );
  }

  void _continue() {
    _onCameraIdle();

    final controller = ref.read(machineRegistrationControllerProvider.notifier);
    if (!controller.continueFromPosition()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('自販機の位置を選んでください。')));
      return;
    }

    widget.onContinue?.call();
  }
}

class _FixedCenterPin extends StatelessWidget {
  const _FixedCenterPin();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -20),
        child: Icon(
          Icons.location_pin,
          key: const Key('registrationFixedCenterPin'),
          size: 46,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _PositionGuideCard extends StatelessWidget {
  const _PositionGuideCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      borderRadius: V2Radius.card,
      color: Theme.of(context).colorScheme.surface,
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: V2Spacing.md,
          vertical: V2Spacing.sm,
        ),
        child: Text('地図を動かして、ピンを自販機の位置に合わせてください。', textAlign: TextAlign.center),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.hasSelectedLocation,
    required this.location,
    required this.onContinue,
  });

  final bool hasSelectedLocation;
  final GeoCoordinate? location;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final selected = location;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        V2Spacing.lg,
        V2Spacing.md,
        V2Spacing.lg,
        V2Spacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (selected == null)
            Text(
              '位置を取得中です。取得できない場合も地図を動かして選択できます。',
              key: const Key('registrationPositionStatus'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Text(
              '選択位置: '
              '${selected.latitude.toStringAsFixed(5)}, '
              '${selected.longitude.toStringAsFixed(5)}',
              key: const Key('registrationPositionStatus'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: V2Spacing.sm),
          FilledButton.icon(
            key: const Key('registrationPositionContinueButton'),
            onPressed: hasSelectedLocation ? onContinue : null,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('この位置で次へ'),
          ),
        ],
      ),
    );
  }
}
