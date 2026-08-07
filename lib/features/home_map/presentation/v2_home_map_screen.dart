import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_shadows.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../../app/theme/v2_theme.dart';
import '../../../core/ui/buttons/v2_map_action_button.dart';
import '../../location/application/current_location_controller.dart';
import '../../location/application/current_location_state.dart';
import '../../location/domain/entities/current_location.dart';
import '../../vending_machine/domain/entities/vending_machine.dart';
import '../application/vending_machine_map_controller.dart';
import '../application/vending_machine_map_state.dart';
import '../domain/value_objects/map_viewport_bounds.dart';
import 'vending_machine_marker_kind.dart';

typedef V2HomeMapBuilder = Widget Function(BuildContext context);

class V2HomeMapScreen extends ConsumerStatefulWidget {
  const V2HomeMapScreen({
    super.key,
    this.mapBuilder,
    this.autoLocate = true,
    this.onSearchPressed,
    this.onRegisterPressed,
    this.onProfilePressed,
  });

  /// Test/preview seam. Production leaves this null and renders GoogleMap.
  final V2HomeMapBuilder? mapBuilder;

  final bool autoLocate;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onRegisterPressed;
  final VoidCallback? onProfilePressed;

  @override
  ConsumerState<V2HomeMapScreen> createState() => _V2HomeMapScreenState();
}

class _V2HomeMapScreenState extends ConsumerState<V2HomeMapScreen> {
  static const CameraPosition _fallbackCamera = CameraPosition(
    target: LatLng(36.2048, 138.2529),
    zoom: 5.2,
  );

  static const double _currentLocationZoom = 16;

  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();

    if (widget.autoLocate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(currentLocationControllerProvider.notifier).locate();
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(currentLocationControllerProvider);
    final machineState = ref.watch(vendingMachineMapControllerProvider);

    ref.listen<CurrentLocationState>(currentLocationControllerProvider, (
      previous,
      next,
    ) {
      final location = next.location;
      if (location == null || location == previous?.location) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _moveCamera(location);
        }
      });
    });

    return Theme(
      data: V2Theme.light(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _buildMap(context, locationState, machineState),
                const _AppLabel(),
                _LocationStatusOverlay(
                  state: locationState,
                  onRetry: _retryLocation,
                  onOpenSettings: _openRelevantSettings,
                ),
                _MapDataStatusOverlay(
                  state: machineState,
                  onRetry: _retryMachines,
                ),
                _CurrentLocationButton(onPressed: _recenter),
                _HomeActionCluster(
                  onSearchPressed: widget.onSearchPressed ?? _noop,
                  onRegisterPressed: widget.onRegisterPressed ?? _noop,
                  onProfilePressed: widget.onProfilePressed ?? _noop,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMap(
    BuildContext context,
    CurrentLocationState locationState,
    VendingMachineMapState machineState,
  ) {
    final overrideBuilder = widget.mapBuilder;
    if (overrideBuilder != null) {
      return overrideBuilder(context);
    }

    return GoogleMap(
      key: const Key('v2HomeGoogleMap'),
      initialCameraPosition: _fallbackCamera,
      myLocationEnabled: locationState.hasLocation,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: true,
      markers: _buildMarkers(machineState),
      onMapCreated: (controller) {
        _mapController = controller;

        final location = locationState.location;
        if (location != null) {
          _moveCamera(location);
        }
      },
      onCameraIdle: _loadVisibleMachines,
      onTap: (_) {
        ref.read(vendingMachineMapControllerProvider.notifier).clearSelection();
      },
    );
  }

  Set<Marker> _buildMarkers(VendingMachineMapState state) {
    return state.machines.map((machine) {
      final kind = VendingMachineMarkerKindResolver.resolve(
        machine: machine,
        selectedMachineId: state.selectedMachineId,
      );

      return Marker(
        markerId: MarkerId(machine.id.value),
        position: LatLng(machine.location.latitude, machine.location.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(_markerHue(kind)),
        zIndexInt: kind == VendingMachineMarkerKind.selected ? 1000 : 0,
        onTap: () => _selectMachine(machine),
      );
    }).toSet();
  }

  static double _markerHue(VendingMachineMarkerKind kind) {
    return switch (kind) {
      VendingMachineMarkerKind.selected => BitmapDescriptor.hueViolet,
      VendingMachineMarkerKind.confirmedProducts => BitmapDescriptor.hueAzure,
      VendingMachineMarkerKind.inferredProducts => BitmapDescriptor.hueOrange,
      VendingMachineMarkerKind.locationOnly => BitmapDescriptor.hueCyan,
    };
  }

  Future<void> _loadVisibleMachines() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    final visibleRegion = await controller.getVisibleRegion();
    if (!mounted) {
      return;
    }

    final bounds = MapViewportBounds(
      south: visibleRegion.southwest.latitude,
      west: visibleRegion.southwest.longitude,
      north: visibleRegion.northeast.latitude,
      east: visibleRegion.northeast.longitude,
    );

    await ref
        .read(vendingMachineMapControllerProvider.notifier)
        .loadViewport(bounds);
  }

  Future<void> _selectMachine(VendingMachine machine) async {
    ref
        .read(vendingMachineMapControllerProvider.notifier)
        .selectMachine(machine.id);

    final controller = _mapController;
    if (controller == null) {
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(machine.location.latitude, machine.location.longitude),
      ),
    );
  }

  Future<void> _moveCamera(CurrentLocation location) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(location.latitude, location.longitude),
        _currentLocationZoom,
      ),
    );
  }

  Future<void> _retryLocation() {
    return ref.read(currentLocationControllerProvider.notifier).retry();
  }

  Future<void> _retryMachines() {
    return ref.read(vendingMachineMapControllerProvider.notifier).retry();
  }

  Future<void> _recenter() {
    return ref.read(currentLocationControllerProvider.notifier).locate();
  }

  Future<void> _openRelevantSettings() async {
    final controller = ref.read(currentLocationControllerProvider.notifier);
    final opened = await controller.openRelevantSettings();

    if (!mounted || !opened) {
      return;
    }

    await controller.locate(requestPermissionIfNeeded: false);
  }

  static void _noop() {}
}

class _AppLabel extends StatelessWidget {
  const _AppLabel();

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(V2Spacing.sm),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceElevated.withValues(alpha: 0.96),
              borderRadius: V2Radius.control,
              border: Border.all(color: colors.border),
              boxShadow: V2Shadows.mapFloating,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: V2Spacing.sm,
                vertical: V2Spacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.local_drink_rounded,
                    size: 18,
                    color: colors.primaryStrong,
                  ),
                  const SizedBox(width: V2Spacing.xs),
                  Text(
                    '自販機ナビ',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentLocationButton extends StatelessWidget {
  const _CurrentLocationButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(V2Spacing.sm),
          child: V2MapActionButton(
            key: const Key('currentLocationMapAction'),
            icon: Icons.my_location_rounded,
            semanticLabel: '現在地へ戻る',
            size: 48,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class _HomeActionCluster extends StatelessWidget {
  const _HomeActionCluster({
    required this.onSearchPressed,
    required this.onRegisterPressed,
    required this.onProfilePressed,
  });

  final VoidCallback onSearchPressed;
  final VoidCallback onRegisterPressed;
  final VoidCallback onProfilePressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(right: V2Spacing.md, bottom: V2Spacing.md),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _LabeledMapAction(
              actionKey: const Key('profileMapAction'),
              label: 'マイ',
              icon: Icons.person_rounded,
              onPressed: onProfilePressed,
            ),
            const SizedBox(height: V2Spacing.sm),
            _LabeledMapAction(
              actionKey: const Key('registerMapAction'),
              label: '登録',
              icon: Icons.add_rounded,
              onPressed: onRegisterPressed,
            ),
            const SizedBox(height: V2Spacing.sm),
            _LabeledMapAction(
              actionKey: const Key('searchMapAction'),
              label: '探す',
              icon: Icons.search_rounded,
              size: 64,
              isPrimary: true,
              onPressed: onSearchPressed,
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledMapAction extends StatelessWidget {
  const _LabeledMapAction({
    required this.actionKey,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.size = 50,
    this.isPrimary = false,
  });

  final Key actionKey;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        V2MapActionButton(
          key: actionKey,
          icon: icon,
          semanticLabel: label,
          size: size,
          isPrimary: isPrimary,
          onPressed: onPressed,
        ),
        const SizedBox(height: V2Spacing.xxs),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceElevated.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: V2Spacing.xs,
              vertical: 2,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isPrimary ? colors.primaryStrong : colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapDataStatusOverlay extends StatelessWidget {
  const _MapDataStatusOverlay({required this.state, required this.onRetry});

  final VendingMachineMapState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.machines.isEmpty) {
      return const _MapDataCard(
        key: Key('mapMachineLoading'),
        icon: Icons.location_searching_rounded,
        message: 'この範囲の自販機を読み込んでいます',
        showProgress: true,
      );
    }

    if (state.failure != null) {
      return _MapDataCard(
        key: const Key('mapMachineError'),
        icon: Icons.cloud_off_rounded,
        message: '自販機情報を読み込めませんでした',
        actionLabel: '再試行',
        onAction: onRetry,
      );
    }

    if (state.isEmpty) {
      return const _MapDataCard(
        key: Key('mapMachineEmpty'),
        icon: Icons.location_off_outlined,
        message: 'この範囲には登録された自販機がありません',
      );
    }

    return const SizedBox.shrink();
  }
}

class _MapDataCard extends StatelessWidget {
  const _MapDataCard({
    super.key,
    required this.icon,
    required this.message,
    this.showProgress = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final bool showProgress;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return SafeArea(
      minimum: const EdgeInsets.only(
        left: V2Spacing.md,
        right: 104,
        bottom: V2Spacing.md,
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceElevated.withValues(alpha: 0.97),
            borderRadius: V2Radius.control,
            border: Border.all(color: colors.border),
            boxShadow: V2Shadows.mapFloating,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: V2Spacing.sm,
              vertical: V2Spacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (showProgress)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else
                  Icon(icon, size: 19, color: colors.textSecondary),
                const SizedBox(width: V2Spacing.xs),
                Flexible(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(width: V2Spacing.xs),
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationStatusOverlay extends StatelessWidget {
  const _LocationStatusOverlay({
    required this.state,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final CurrentLocationState state;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final content = _contentFor(state);
    if (content == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      minimum: const EdgeInsets.only(
        top: 64,
        left: V2Spacing.md,
        right: V2Spacing.md,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _LocationStatusCard(
            content: content,
            onRetry: onRetry,
            onOpenSettings: onOpenSettings,
          ),
        ),
      ),
    );
  }

  static _LocationStatusContent? _contentFor(CurrentLocationState state) {
    return switch (state.phase) {
      CurrentLocationPhase.idle => null,
      CurrentLocationPhase.ready => null,
      CurrentLocationPhase.loading => const _LocationStatusContent(
        icon: Icons.my_location_rounded,
        title: '現在地を確認しています',
        message: '地図はそのまま操作できます。',
        action: _LocationStatusAction.none,
        isLoading: true,
      ),
      CurrentLocationPhase.serviceDisabled => const _LocationStatusContent(
        icon: Icons.location_disabled_rounded,
        title: '位置情報がオフです',
        message: '現在地から探すには、端末の位置情報をオンにしてください。',
        action: _LocationStatusAction.settings,
      ),
      CurrentLocationPhase.permissionDenied => const _LocationStatusContent(
        icon: Icons.location_off_rounded,
        title: '現在地の利用が許可されていません',
        message: '許可しなくても地図は利用できます。現在地を使う場合は、もう一度確認してください。',
        action: _LocationStatusAction.retry,
      ),
      CurrentLocationPhase.permissionDeniedForever =>
        const _LocationStatusContent(
          icon: Icons.location_off_rounded,
          title: '位置情報の許可が必要です',
          message: '端末のアプリ設定から位置情報を許可すると、現在地から探せます。',
          action: _LocationStatusAction.settings,
        ),
      CurrentLocationPhase.permissionUnableToDetermine =>
        const _LocationStatusContent(
          icon: Icons.location_searching_rounded,
          title: '位置情報の権限を確認できませんでした',
          message: '地図は利用できます。必要に応じて、もう一度お試しください。',
          action: _LocationStatusAction.retry,
        ),
      CurrentLocationPhase.failed => _LocationStatusContent(
        icon: Icons.location_searching_rounded,
        title: state.failure?.userTitle ?? '現在地を取得できませんでした',
        message: state.failure?.userMessage ?? '少し時間をおいて、もう一度お試しください。',
        action: _LocationStatusAction.retry,
      ),
    };
  }
}

enum _LocationStatusAction { none, retry, settings }

class _LocationStatusContent {
  const _LocationStatusContent({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final _LocationStatusAction action;
  final bool isLoading;
}

class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({
    required this.content,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final _LocationStatusContent content;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated.withValues(alpha: 0.97),
        borderRadius: V2Radius.card,
        border: Border.all(color: colors.border),
        boxShadow: V2Shadows.mapFloating,
      ),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (content.isLoading)
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            else
              Icon(content.icon, size: 22, color: colors.primaryStrong),
            const SizedBox(width: V2Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    content.title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: V2Spacing.xxs),
                  Text(
                    content.message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (content.action != _LocationStatusAction.none) ...<Widget>[
              const SizedBox(width: V2Spacing.xs),
              TextButton(
                onPressed: content.action == _LocationStatusAction.settings
                    ? onOpenSettings
                    : onRetry,
                child: Text(
                  content.action == _LocationStatusAction.settings
                      ? '設定を開く'
                      : '再試行',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
