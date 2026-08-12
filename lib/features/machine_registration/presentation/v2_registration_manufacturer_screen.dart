import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../product_master/domain/entities/manufacturer.dart';
import '../application/machine_registration_controller.dart';
import '../application/manufacturer_selection_controller.dart';
import '../application/manufacturer_selection_state.dart';

typedef RegistrationManufacturerCallback =
    void Function(Manufacturer manufacturer);

class V2RegistrationManufacturerScreen extends ConsumerStatefulWidget {
  const V2RegistrationManufacturerScreen({
    super.key,
    this.onManufacturerSelected,
    this.onUnknownSelected,
  });

  /// P6-08 final-confirmation connection point.
  final RegistrationManufacturerCallback? onManufacturerSelected;

  /// P6-08 location-only confirmation connection point.
  final VoidCallback? onUnknownSelected;

  @override
  ConsumerState<V2RegistrationManufacturerScreen> createState() =>
      _V2RegistrationManufacturerScreenState();
}

class _V2RegistrationManufacturerScreenState
    extends ConsumerState<V2RegistrationManufacturerScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(manufacturerSelectionControllerProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manufacturerSelectionControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('メーカーを選択')),
      body: SafeArea(
        child: _Body(
          state: state,
          onRetry: () {
            ref.read(manufacturerSelectionControllerProvider.notifier).retry();
          },
          onManufacturerSelected: _selectManufacturer,
          onUnknownSelected: _selectUnknown,
        ),
      ),
    );
  }

  void _selectManufacturer(Manufacturer manufacturer) {
    ref
        .read(machineRegistrationControllerProvider.notifier)
        .selectManufacturer(manufacturer.id);
    widget.onManufacturerSelected?.call(manufacturer);
  }

  void _selectUnknown() {
    ref
        .read(machineRegistrationControllerProvider.notifier)
        .chooseLocationOnly();
    widget.onUnknownSelected?.call();
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.onRetry,
    required this.onManufacturerSelected,
    required this.onUnknownSelected,
  });

  final ManufacturerSelectionState state;
  final VoidCallback onRetry;
  final RegistrationManufacturerCallback onManufacturerSelected;
  final VoidCallback onUnknownSelected;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading || !state.hasLoaded) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('registrationManufacturerLoading'),
        ),
      );
    }

    final failure = state.failure;
    if (failure != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(V2Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: V2Spacing.sm),
              Text(
                failure.userTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: V2Spacing.xs),
              Text(failure.userMessage, textAlign: TextAlign.center),
              const SizedBox(height: V2Spacing.md),
              FilledButton.icon(
                key: const Key('registrationManufacturerRetryButton'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('もう一度読み込む'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      key: const Key('registrationManufacturerList'),
      padding: const EdgeInsets.all(V2Spacing.lg),
      children: <Widget>[
        Text(
          '自販機のメーカーは？',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: V2Spacing.xs),
        const Text('メーカーを選ぶと、代表商品を「あるかも」として表示します。実物の商品登録はあとから追加できます。'),
        const SizedBox(height: V2Spacing.lg),
        for (final manufacturer in state.manufacturers) ...<Widget>[
          _ManufacturerCard(
            manufacturer: manufacturer,
            onPressed: () => onManufacturerSelected(manufacturer),
          ),
          const SizedBox(height: V2Spacing.sm),
        ],
        _UnknownManufacturerCard(onPressed: onUnknownSelected),
        if (state.isEmpty) ...<Widget>[
          const SizedBox(height: V2Spacing.md),
          Text(
            '現在選べるメーカーマスタがありません。「分からない」から位置のみ登録できます。',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _ManufacturerCard extends StatelessWidget {
  const _ManufacturerCard({
    required this.manufacturer,
    required this.onPressed,
  });

  final Manufacturer manufacturer;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.card),
      child: InkWell(
        key: Key('registrationManufacturer_${manufacturer.id.value}'),
        borderRadius: V2Radius.card,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(V2Spacing.md),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                child: Text(
                  _initial(manufacturer.displayShortName),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: V2Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      manufacturer.displayShortName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (manufacturer.name != manufacturer.displayShortName) ...[
                      const SizedBox(height: V2Spacing.xxs),
                      Text(
                        manufacturer.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (manufacturer.presetProductIds.isNotEmpty) ...[
                      const SizedBox(height: V2Spacing.xxs),
                      Text(
                        '代表商品 ${manufacturer.presetProductIds.length}件',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  static String _initial(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return '?';
    }
    return normalized.substring(0, 1);
  }
}

class _UnknownManufacturerCard extends StatelessWidget {
  const _UnknownManufacturerCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.card),
      child: InkWell(
        key: const Key('registrationManufacturerUnknown'),
        borderRadius: V2Radius.card,
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(V2Spacing.md),
          child: Row(
            children: <Widget>[
              CircleAvatar(child: Icon(Icons.question_mark_rounded)),
              SizedBox(width: V2Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '分からない',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: V2Spacing.xxs),
                    Text('メーカーや商品を推定せず、位置だけ登録します。'),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
