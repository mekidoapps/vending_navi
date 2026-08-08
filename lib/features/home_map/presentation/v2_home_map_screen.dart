import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_shadows.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../../app/theme/v2_theme.dart';
import '../../../core/ui/badges/v2_status_badge.dart';
import '../../../core/ui/buttons/v2_map_action_button.dart';
import '../../../app/router/app_route.dart';
import '../../location/application/current_location_controller.dart';
import '../../product_master/domain/entities/product.dart';
import '../../product_master/domain/entities/product_genre.dart';
import '../../product_search/application/genre_machine_search_controller.dart';
import '../../product_search/application/genre_machine_search_state.dart';
import '../../product_search/application/genre_search_map_filter.dart';
import '../../product_search/application/genre_search_selection_controller.dart';
import '../../product_search/application/product_machine_search_controller.dart';
import '../../product_search/application/product_machine_search_state.dart';
import '../../product_search/application/product_search_controller.dart';
import '../../product_search/application/product_search_map_filter.dart';
import '../../product_search/application/product_search_selection_controller.dart';
import '../../product_search/presentation/v2_product_search_panel.dart';
import '../../product_search/presentation/v2_selected_genre_label.dart';
import '../../product_search/presentation/v2_selected_product_label.dart';
import '../../location/application/current_location_state.dart';
import '../../location/domain/entities/current_location.dart';
import '../../vending_machine/application/providers/vending_machine_detail_providers.dart';
import '../../vending_machine/domain/entities/vending_machine.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../application/vending_machine_map_controller.dart';
import '../application/vending_machine_map_state.dart';
import '../domain/value_objects/map_viewport_bounds.dart';
import 'genre_search_marker_kind_resolver.dart';
import 'product_search_marker_kind_resolver.dart';
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
    this.onMachineDetailPressed,
  });

  /// Test/preview seam. Production leaves this null and renders GoogleMap.
  final V2HomeMapBuilder? mapBuilder;

  final bool autoLocate;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onRegisterPressed;
  final VoidCallback? onProfilePressed;
  final ValueChanged<VendingMachine>? onMachineDetailPressed;

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
  bool _isProductSearchPanelOpen = false;

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
    final selectedProduct = ref.watch(productSearchSelectionControllerProvider);
    final selectedGenre = ref.watch(genreSearchSelectionControllerProvider);
    final productMachineSearchState = ref.watch(
      productMachineSearchControllerProvider,
    );
    final genreMachineSearchState = ref.watch(
      genreMachineSearchControllerProvider,
    );

    final visibleMachines = _visibleMachinesForSearch(
      machineState: machineState,
      selectedProduct: selectedProduct,
      selectedGenre: selectedGenre,
      productSearchState: productMachineSearchState,
      genreSearchState: genreMachineSearchState,
    );

    final visibleSelectedMachine = machineState.selectedMachine;
    final selectedMachineForBubble =
        visibleSelectedMachine != null &&
            visibleMachines.any(
              (machine) => machine.id == visibleSelectedMachine.id,
            )
        ? visibleSelectedMachine
        : null;

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
                _buildMap(
                  context,
                  locationState,
                  machineState,
                  selectedProduct,
                  selectedGenre,
                  productMachineSearchState,
                  genreMachineSearchState,
                ),
                const _AppLabel(),
                _LocationStatusOverlay(
                  state: locationState,
                  onRetry: _retryLocation,
                  onOpenSettings: _openRelevantSettings,
                ),
                if (selectedProduct != null)
                  _ProductSearchResultStatusOverlay(
                    product: selectedProduct,
                    machineState: machineState,
                    state: productMachineSearchState,
                    visibleResultCount: visibleMachines.length,
                    onRetry: _retryProductSearchFlow,
                  )
                else if (selectedGenre != null)
                  _GenreSearchResultStatusOverlay(
                    genre: selectedGenre,
                    machineState: machineState,
                    state: genreMachineSearchState,
                    visibleResultCount: visibleMachines.length,
                    onRetry: _retryGenreSearchFlow,
                  )
                else
                  _MapDataStatusOverlay(
                    state: machineState,
                    onRetry: _retryMachines,
                  ),
                _SelectedMachineBubble(
                  machine: selectedMachineForBubble,
                  onDetailPressed: _openMachineDetail,
                ),
                if (!_isProductSearchPanelOpen &&
                    _canShowSelectedSearchLabel(locationState))
                  if (selectedProduct != null)
                    _SelectedProductOverlay(
                      product: selectedProduct,
                      onClear: _clearSelectedProduct,
                    )
                  else if (selectedGenre != null)
                    _SelectedGenreOverlay(
                      genre: selectedGenre,
                      onClear: _clearSelectedGenre,
                    ),
                _ProductSearchPanelOverlay(
                  isOpen: _isProductSearchPanelOpen,
                  onClose: _closeProductSearchPanel,
                  onProductSelected: _selectProduct,
                  onGenreSelected: _selectGenre,
                ),
                _CurrentLocationButton(onPressed: _recenter),
                _HomeActionCluster(
                  onSearchPressed: _toggleProductSearchPanel,
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
    Product? selectedProduct,
    ProductGenre? selectedGenre,
    ProductMachineSearchState productMachineSearchState,
    GenreMachineSearchState genreMachineSearchState,
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
      markers: _buildMarkers(
        machineState,
        selectedProduct,
        selectedGenre,
        productMachineSearchState,
        genreMachineSearchState,
      ),
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

  Set<Marker> _buildMarkers(
    VendingMachineMapState state,
    Product? selectedProduct,
    ProductGenre? selectedGenre,
    ProductMachineSearchState productMachineSearchState,
    GenreMachineSearchState genreMachineSearchState,
  ) {
    final visibleMachines = _visibleMachinesForSearch(
      machineState: state,
      selectedProduct: selectedProduct,
      selectedGenre: selectedGenre,
      productSearchState: productMachineSearchState,
      genreSearchState: genreMachineSearchState,
    );

    return visibleMachines.map((machine) {
      final kind = _markerKindForSearch(
        machine: machine,
        selectedMachineId: state.selectedMachineId,
        selectedProduct: selectedProduct,
        selectedGenre: selectedGenre,
        productSearchState: productMachineSearchState,
        genreSearchState: genreMachineSearchState,
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

  static List<VendingMachine> _visibleMachinesForSearch({
    required VendingMachineMapState machineState,
    required Product? selectedProduct,
    required ProductGenre? selectedGenre,
    required ProductMachineSearchState productSearchState,
    required GenreMachineSearchState genreSearchState,
  }) {
    if (selectedProduct != null) {
      return ProductSearchMapFilter.visibleMachines(
        machines: machineState.machines,
        selectedProduct: selectedProduct,
        searchState: productSearchState,
      );
    }

    if (selectedGenre != null) {
      return GenreSearchMapFilter.visibleMachines(
        machines: machineState.machines,
        selectedGenre: selectedGenre,
        searchState: genreSearchState,
      );
    }

    return List<VendingMachine>.unmodifiable(machineState.machines);
  }

  static VendingMachineMarkerKind _markerKindForSearch({
    required VendingMachine machine,
    required VendingMachineId? selectedMachineId,
    required Product? selectedProduct,
    required ProductGenre? selectedGenre,
    required ProductMachineSearchState productSearchState,
    required GenreMachineSearchState genreSearchState,
  }) {
    if (selectedProduct != null) {
      return ProductSearchMarkerKindResolver.resolve(
        machine: machine,
        selectedMachineId: selectedMachineId,
        selectedProduct: selectedProduct,
        searchState: productSearchState,
      );
    }

    if (selectedGenre != null) {
      return GenreSearchMarkerKindResolver.resolve(
        machine: machine,
        selectedMachineId: selectedMachineId,
        selectedGenre: selectedGenre,
        searchState: genreSearchState,
      );
    }

    return VendingMachineMarkerKindResolver.resolve(
      machine: machine,
      selectedMachineId: selectedMachineId,
    );
  }

  static double _markerHue(VendingMachineMarkerKind kind) {
    return switch (kind) {
      VendingMachineMarkerKind.selected => BitmapDescriptor.hueViolet,
      VendingMachineMarkerKind.confirmedProducts => BitmapDescriptor.hueAzure,
      VendingMachineMarkerKind.inferredProducts => BitmapDescriptor.hueOrange,
      VendingMachineMarkerKind.locationOnly => BitmapDescriptor.hueCyan,
    };
  }

  Future<void> _loadVisibleMachines({
    Product? productOverride,
    ProductGenre? genreOverride,
    bool forceProductSearch = false,
    bool forceGenreSearch = false,
  }) async {
    final controller = _mapController;

    MapViewportBounds? bounds;
    if (controller != null) {
      final visibleRegion = await controller.getVisibleRegion();
      if (!mounted) {
        return;
      }

      bounds = MapViewportBounds(
        south: visibleRegion.southwest.latitude,
        west: visibleRegion.southwest.longitude,
        north: visibleRegion.northeast.latitude,
        east: visibleRegion.northeast.longitude,
      );

      await ref
          .read(vendingMachineMapControllerProvider.notifier)
          .loadViewport(bounds);
    } else {
      bounds = ref.read(vendingMachineMapControllerProvider).lastViewport;
    }

    if (!mounted || bounds == null) {
      return;
    }

    final product =
        productOverride ?? ref.read(productSearchSelectionControllerProvider);
    final genre =
        genreOverride ?? ref.read(genreSearchSelectionControllerProvider);

    if (product != null) {
      ref.read(genreMachineSearchControllerProvider.notifier).clear();

      await ref
          .read(productMachineSearchControllerProvider.notifier)
          .search(
            productId: product.id,
            viewport: bounds,
            force: forceProductSearch,
          );

      if (mounted) {
        _clearMachineSelectionIfProductFilteredOut(product);
      }
      return;
    }

    if (genre != null) {
      ref.read(productMachineSearchControllerProvider.notifier).clear();

      await ref
          .read(genreMachineSearchControllerProvider.notifier)
          .search(genre: genre, viewport: bounds, force: forceGenreSearch);

      if (mounted) {
        _clearMachineSelectionIfGenreFilteredOut(genre);
      }
      return;
    }

    ref.read(productMachineSearchControllerProvider.notifier).clear();
    ref.read(genreMachineSearchControllerProvider.notifier).clear();
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

  void _openMachineDetail(VendingMachine machine) {
    final override = widget.onMachineDetailPressed;
    if (override != null) {
      override(machine);
      return;
    }

    context.pushNamed(
      AppRoute.v2MachineDetail.name,
      pathParameters: <String, String>{'machineId': machine.id.value},
    );
  }

  void _toggleProductSearchPanel() {
    setState(() {
      _isProductSearchPanelOpen = !_isProductSearchPanelOpen;
    });
    widget.onSearchPressed?.call();
  }

  void _closeProductSearchPanel() {
    if (!_isProductSearchPanelOpen) {
      return;
    }

    ref.read(productSearchControllerProvider.notifier).clear();
    setState(() {
      _isProductSearchPanelOpen = false;
    });
  }

  void _selectProduct(Product product) {
    ref.read(genreSearchSelectionControllerProvider.notifier).clear();
    ref.read(genreMachineSearchControllerProvider.notifier).clear();
    ref.read(productSearchSelectionControllerProvider.notifier).select(product);
    ref.read(productSearchControllerProvider.notifier).clear();
    ref.read(vendingMachineMapControllerProvider.notifier).clearSelection();

    setState(() {
      _isProductSearchPanelOpen = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadVisibleMachines(productOverride: product, forceProductSearch: true);
    });
  }

  void _selectGenre(ProductGenre genre) {
    ref.read(productSearchSelectionControllerProvider.notifier).clear();
    ref.read(productMachineSearchControllerProvider.notifier).clear();
    ref.read(genreSearchSelectionControllerProvider.notifier).select(genre);
    ref.read(productSearchControllerProvider.notifier).clear();
    ref.read(vendingMachineMapControllerProvider.notifier).clearSelection();

    setState(() {
      _isProductSearchPanelOpen = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadVisibleMachines(genreOverride: genre, forceGenreSearch: true);
    });
  }

  void _clearSelectedProduct() {
    ref.read(productSearchSelectionControllerProvider.notifier).clear();
    ref.read(productMachineSearchControllerProvider.notifier).clear();
  }

  void _clearSelectedGenre() {
    ref.read(genreSearchSelectionControllerProvider.notifier).clear();
    ref.read(genreMachineSearchControllerProvider.notifier).clear();
  }

  void _clearMachineSelectionIfProductFilteredOut(Product product) {
    final mapState = ref.read(vendingMachineMapControllerProvider);
    final selectedId = mapState.selectedMachineId;
    if (selectedId == null) {
      return;
    }

    final searchState = ref.read(productMachineSearchControllerProvider);
    final visibleMachines = ProductSearchMapFilter.visibleMachines(
      machines: mapState.machines,
      selectedProduct: product,
      searchState: searchState,
    );

    if (ProductSearchMapFilter.containsMachine(
      machineId: selectedId,
      visibleMachines: visibleMachines,
    )) {
      return;
    }

    ref.read(vendingMachineMapControllerProvider.notifier).clearSelection();
  }

  void _clearMachineSelectionIfGenreFilteredOut(ProductGenre genre) {
    final mapState = ref.read(vendingMachineMapControllerProvider);
    final selectedId = mapState.selectedMachineId;
    if (selectedId == null) {
      return;
    }

    final searchState = ref.read(genreMachineSearchControllerProvider);
    final visibleMachines = GenreSearchMapFilter.visibleMachines(
      machines: mapState.machines,
      selectedGenre: genre,
      searchState: searchState,
    );

    if (GenreSearchMapFilter.containsMachine(
      machineId: selectedId,
      visibleMachines: visibleMachines,
    )) {
      return;
    }

    ref.read(vendingMachineMapControllerProvider.notifier).clearSelection();
  }

  static bool _canShowSelectedSearchLabel(CurrentLocationState state) {
    return state.phase == CurrentLocationPhase.idle ||
        state.phase == CurrentLocationPhase.ready;
  }

  Future<void> _retryLocation() {
    return ref.read(currentLocationControllerProvider.notifier).retry();
  }

  Future<void> _retryMachines() {
    return ref.read(vendingMachineMapControllerProvider.notifier).retry();
  }

  Future<void> _retryProductSearchFlow() async {
    await ref.read(vendingMachineMapControllerProvider.notifier).retry();

    if (!mounted) {
      return;
    }

    final product = ref.read(productSearchSelectionControllerProvider);
    final viewport = ref.read(vendingMachineMapControllerProvider).lastViewport;

    if (product == null || viewport == null) {
      return;
    }

    await ref
        .read(productMachineSearchControllerProvider.notifier)
        .search(productId: product.id, viewport: viewport, force: true);

    if (mounted) {
      _clearMachineSelectionIfProductFilteredOut(product);
    }
  }

  Future<void> _retryGenreSearchFlow() async {
    await ref.read(vendingMachineMapControllerProvider.notifier).retry();

    if (!mounted) {
      return;
    }

    final genre = ref.read(genreSearchSelectionControllerProvider);
    final viewport = ref.read(vendingMachineMapControllerProvider).lastViewport;

    if (genre == null || viewport == null) {
      return;
    }

    await ref
        .read(genreMachineSearchControllerProvider.notifier)
        .search(genre: genre, viewport: viewport, force: true);

    if (mounted) {
      _clearMachineSelectionIfGenreFilteredOut(genre);
    }
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

class _SelectedProductOverlay extends StatelessWidget {
  const _SelectedProductOverlay({required this.product, required this.onClear});

  final Product product;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(top: 62, left: V2Spacing.sm, right: 76),
      child: Align(
        alignment: Alignment.topLeft,
        child: V2SelectedProductLabel(product: product, onClear: onClear),
      ),
    );
  }
}

class _SelectedGenreOverlay extends StatelessWidget {
  const _SelectedGenreOverlay({required this.genre, required this.onClear});

  final ProductGenre genre;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(top: 62, left: V2Spacing.sm, right: 76),
      child: Align(
        alignment: Alignment.topLeft,
        child: V2SelectedGenreLabel(genre: genre, onClear: onClear),
      ),
    );
  }
}

class _ProductSearchPanelOverlay extends StatelessWidget {
  const _ProductSearchPanelOverlay({
    required this.isOpen,
    required this.onClose,
    required this.onProductSelected,
    required this.onGenreSelected,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final ValueChanged<Product> onProductSelected;
  final ValueChanged<ProductGenre> onGenreSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(
        left: V2Spacing.sm,
        right: 104,
        bottom: V2Spacing.md,
      ),
      child: Align(
        alignment: Alignment.bottomRight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final panelWidth = constraints.maxWidth
                .clamp(196.0, 360.0)
                .toDouble();
            final desiredPanelHeight = (constraints.maxHeight * 0.70)
                .clamp(320.0, 460.0)
                .toDouble();
            final panelHeight = desiredPanelHeight
                .clamp(0.0, constraints.maxHeight)
                .toDouble();

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              reverseDuration: const Duration(milliseconds: 140),
              transitionBuilder: (child, animation) {
                final offset =
                    Tween<Offset>(
                      begin: const Offset(0.12, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: isOpen
                  ? SizedBox(
                      key: const ValueKey<String>('productSearchOpen'),
                      width: panelWidth,
                      height: panelHeight,
                      child: V2ProductSearchPanel(
                        onProductSelected: onProductSelected,
                        onGenreSelected: onGenreSelected,
                        onClose: onClose,
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey<String>('productSearchClosed'),
                    ),
            );
          },
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

class _SelectedMachineSearchMatch extends ConsumerWidget {
  const _SelectedMachineSearchMatch({required this.machine});

  final VendingMachine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProduct = ref.watch(productSearchSelectionControllerProvider);
    final selectedGenre = ref.watch(genreSearchSelectionControllerProvider);

    if (selectedProduct == null && selectedGenre == null) {
      return const SizedBox.shrink();
    }

    final colors = V2ColorTokens.of(context);
    final productState = ref.watch(productMachineSearchControllerProvider);
    final genreState = ref.watch(genreMachineSearchControllerProvider);

    final evidence = selectedProduct != null
        ? ProductSearchMapFilter.evidenceForMachine(
            machine: machine,
            selectedProduct: selectedProduct,
            searchState: productState,
          )
        : GenreSearchMapFilter.evidenceForMachine(
            machine: machine,
            searchState: genreState,
          );

    final label = selectedProduct?.name ?? '${selectedGenre!.label}の商品';

    return DecoratedBox(
      key: const Key('selectedMachineSearchMatch'),
      decoration: BoxDecoration(
        color: colors.surfaceTint,
        borderRadius: V2Radius.control,
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: V2Spacing.sm,
          vertical: V2Spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.search_rounded, size: 18, color: colors.primaryStrong),
            const SizedBox(width: V2Spacing.xs),
            Expanded(
              child: Text(
                label,
                key: const Key('selectedMachineSearchMatchLabel'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: V2Spacing.xs),
            if (evidence?.isConfirmed ?? false)
              const V2StatusBadge(type: V2StatusBadgeType.confirmed)
            else if (evidence?.isInferred ?? false)
              const V2StatusBadge(type: V2StatusBadgeType.inferred),
          ],
        ),
      ),
    );
  }
}

class _SelectedMachineBubble extends ConsumerWidget {
  const _SelectedMachineBubble({
    required this.machine,
    required this.onDetailPressed,
  });

  final VendingMachine? machine;
  final ValueChanged<VendingMachine> onDetailPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = machine;
    if (selected == null) {
      return const SizedBox.shrink();
    }

    final colors = V2ColorTokens.of(context);
    final manufacturerName = ref.watch(
      manufacturerDisplayNameProvider(selected.manufacturerId),
    );

    return SafeArea(
      minimum: const EdgeInsets.only(
        left: V2Spacing.md,
        right: 104,
        bottom: V2Spacing.md,
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceElevated.withValues(alpha: 0.98),
              borderRadius: V2Radius.card,
              border: Border.all(color: colors.primary.withValues(alpha: 0.50)),
              boxShadow: V2Shadows.mapFloating,
            ),
            child: Padding(
              padding: const EdgeInsets.all(V2Spacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              selected.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: V2Spacing.xxs),
                            manufacturerName.when(
                              data: (name) => Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.textSecondary),
                              ),
                              loading: () => Text(
                                'メーカー確認中',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.textSecondary),
                              ),
                              error: (_, _) => Text(
                                selected.manufacturerId?.value ?? 'メーカー不明',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: V2Spacing.sm),
                      IconButton(
                        tooltip: '選択を解除',
                        onPressed: () {
                          ref
                              .read(
                                vendingMachineMapControllerProvider.notifier,
                              )
                              .clearSelection();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: V2Spacing.xs),
                  _SelectedMachineSearchMatch(machine: selected),
                  const SizedBox(height: V2Spacing.xs),
                  Wrap(
                    spacing: V2Spacing.xs,
                    runSpacing: V2Spacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if (selected.confirmedProducts.isNotEmpty)
                        const V2StatusBadge(type: V2StatusBadgeType.confirmed)
                      else if (selected.inferredProducts.isNotEmpty)
                        const V2StatusBadge(type: V2StatusBadgeType.inferred)
                      else
                        Text(
                          '商品情報なし',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      Text(
                        '商品 ${selected.activeProducts.length}件',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (selected.placeDescription?.trim().isNotEmpty ==
                      true) ...<Widget>[
                    const SizedBox(height: V2Spacing.xs),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.place_outlined,
                          size: 17,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: V2Spacing.xxs),
                        Expanded(
                          child: Text(
                            selected.placeDescription!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: V2Spacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      key: const Key('selectedMachineDetailButton'),
                      onPressed: () => onDetailPressed(selected),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('詳細を見る'),
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

class _GenreSearchResultStatusOverlay extends StatelessWidget {
  const _GenreSearchResultStatusOverlay({
    required this.genre,
    required this.machineState,
    required this.state,
    required this.visibleResultCount,
    required this.onRetry,
  });

  final ProductGenre genre;
  final VendingMachineMapState machineState;
  final GenreMachineSearchState state;
  final int visibleResultCount;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (machineState.failure != null) {
      return _MapDataCard(
        key: const Key('genreSearchMachineLoadError'),
        icon: Icons.cloud_off_rounded,
        message: '自販機情報を読み込めませんでした',
        actionLabel: '再試行',
        onAction: onRetry,
      );
    }

    if (machineState.isLoading ||
        state.isLoading ||
        state.genre != genre ||
        !state.hasSearched) {
      return _MapDataCard(
        key: const Key('genreMachineSearchLoading'),
        icon: Icons.category_outlined,
        message: '「${genre.label}」のある自販機を探しています',
        showProgress: true,
      );
    }

    if (state.failure != null) {
      return _MapDataCard(
        key: const Key('genreMachineSearchError'),
        icon: Icons.cloud_off_rounded,
        message: 'ジャンル検索結果を読み込めませんでした',
        actionLabel: '再試行',
        onAction: onRetry,
      );
    }

    if (visibleResultCount == 0) {
      return _MapDataCard(
        key: const Key('genreMachineSearchEmpty'),
        icon: Icons.search_off_rounded,
        message: 'この範囲では「${genre.label}」が見つかりませんでした',
      );
    }

    return const SizedBox.shrink();
  }
}

class _ProductSearchResultStatusOverlay extends StatelessWidget {
  const _ProductSearchResultStatusOverlay({
    required this.product,
    required this.machineState,
    required this.state,
    required this.visibleResultCount,
    required this.onRetry,
  });

  final Product product;
  final VendingMachineMapState machineState;
  final ProductMachineSearchState state;
  final int visibleResultCount;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (machineState.failure != null) {
      return _MapDataCard(
        key: const Key('productSearchMachineLoadError'),
        icon: Icons.cloud_off_rounded,
        message: '自販機情報を読み込めませんでした',
        actionLabel: '再試行',
        onAction: onRetry,
      );
    }

    if (machineState.isLoading ||
        state.isLoading ||
        state.productId != product.id ||
        !state.hasSearched) {
      return _MapDataCard(
        key: const Key('productMachineSearchLoading'),
        icon: Icons.search_rounded,
        message: '「${product.name}」のある自販機を探しています',
        showProgress: true,
      );
    }

    if (state.failure != null) {
      return _MapDataCard(
        key: const Key('productMachineSearchError'),
        icon: Icons.cloud_off_rounded,
        message: '商品検索結果を読み込めませんでした',
        actionLabel: '再試行',
        onAction: onRetry,
      );
    }

    if (visibleResultCount == 0) {
      return _MapDataCard(
        key: const Key('productMachineSearchEmpty'),
        icon: Icons.search_off_rounded,
        message: 'この範囲では「${product.name}」が見つかりませんでした',
      );
    }

    return const SizedBox.shrink();
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
