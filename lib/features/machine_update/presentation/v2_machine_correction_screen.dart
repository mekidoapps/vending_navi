import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../../app/theme/v2_theme.dart';
import '../../../core/ui/states/v2_error_state.dart';
import '../../../core/ui/states/v2_loading_state.dart';
import '../../product_master/domain/entities/manufacturer.dart';
import '../../product_master/domain/value_objects/master_id.dart';
import '../../vending_machine/application/models/vending_machine_detail_data.dart';
import '../../vending_machine/application/providers/vending_machine_detail_providers.dart';
import '../../vending_machine/domain/entities/vending_machine_enums.dart';
import '../../vending_machine/domain/value_objects/geo_coordinate.dart';
import '../../vending_machine/domain/value_objects/vending_machine_id.dart';
import '../application/machine_correction_controller.dart';
import '../application/machine_correction_draft_builder.dart';
import '../application/providers/machine_correction_providers.dart';
import 'v2_machine_correction_position_sheet.dart';

typedef MachineCorrectionPositionPicker =
    Future<GeoCoordinate?> Function(
      BuildContext context,
      GeoCoordinate initialLocation,
    );

class V2MachineCorrectionScreen extends ConsumerStatefulWidget {
  const V2MachineCorrectionScreen({
    super.key,
    required this.machineId,
    this.onReviewPressed,
    this.positionPicker,
  });

  final VendingMachineId machineId;
  final VoidCallback? onReviewPressed;

  /// Widget-test seam. Production uses the Google Maps position sheet.
  final MachineCorrectionPositionPicker? positionPicker;

  @override
  ConsumerState<V2MachineCorrectionScreen> createState() =>
      _V2MachineCorrectionScreenState();
}

class _V2MachineCorrectionScreenState
    extends ConsumerState<V2MachineCorrectionScreen> {
  static const String _unknownManufacturerValue = '__unknown__';

  final _nameController = TextEditingController();
  final _placeController = TextEditingController();

  VendingMachineId? _initializedMachineId;
  String _selectedManufacturerValue = _unknownManufacturerValue;
  GeoCoordinate? _selectedLocation;
  InstallationType _selectedInstallationType = InstallationType.unknown;

  @override
  void dispose() {
    _nameController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(vendingMachineDetailProvider(widget.machineId));

    return Theme(
      data: V2Theme.light(),
      child: Scaffold(
        appBar: AppBar(title: const Text('基本情報の修正を提案')),
        body: SafeArea(
          child: detail.when(
            loading: () => const V2LoadingState(message: '現在の自販機情報を読み込んでいます'),
            error: (_, _) => V2ErrorState(
              title: '自販機情報を読み込めませんでした',
              message: '時間をおいて、もう一度お試しください。',
              onRetry: () {
                ref.invalidate(vendingMachineDetailProvider(widget.machineId));
              },
            ),
            data: (result) => result.fold(
              onSuccess: _buildContent,
              onFailure: (failure) => V2ErrorState(
                title: failure.userTitle,
                message: failure.userMessage,
                onRetry: failure.isRetryable
                    ? () {
                        ref.invalidate(
                          vendingMachineDetailProvider(widget.machineId),
                        );
                      }
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(VendingMachineDetailData data) {
    _ensureInitialized(data);

    final colors = V2ColorTokens.of(context);
    final location = _selectedLocation!;

    return ListView(
      key: const Key('machineCorrectionScreen'),
      padding: const EdgeInsets.all(V2Spacing.md),
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceTint,
            borderRadius: V2Radius.card,
          ),
          child: const Padding(
            padding: EdgeInsets.all(V2Spacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline_rounded),
                SizedBox(width: V2Spacing.sm),
                Expanded(
                  child: Text('ここで入力した内容はすぐには反映されません。修正提案として送信され、確認後に反映されます。'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: V2Spacing.lg),
        TextField(
          key: const Key('machineCorrectionNameField'),
          controller: _nameController,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: '名前',
            hintText: '自販機の名前',
          ),
        ),
        const SizedBox(height: V2Spacing.sm),
        _ManufacturerField(
          currentManufacturerId: data.machine.manufacturerId,
          currentManufacturerName: data.manufacturerName,
          selectedValue: _selectedManufacturerValue,
          unknownValue: _unknownManufacturerValue,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _selectedManufacturerValue = value;
            });
          },
        ),
        const SizedBox(height: V2Spacing.md),
        _FieldCard(
          title: '位置',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '${location.latitude.toStringAsFixed(5)}, '
                '${location.longitude.toStringAsFixed(5)}',
                key: const Key('machineCorrectionLocationValue'),
              ),
              const SizedBox(height: V2Spacing.sm),
              OutlinedButton.icon(
                key: const Key('machineCorrectionLocationButton'),
                onPressed: _chooseLocation,
                icon: const Icon(Icons.map_outlined),
                label: const Text('地図で位置を修正'),
              ),
            ],
          ),
        ),
        const SizedBox(height: V2Spacing.md),
        TextField(
          key: const Key('machineCorrectionPlaceField'),
          controller: _placeController,
          maxLength: 300,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '場所メモ',
            hintText: '例：駅東口の壁沿い',
            helperText: '空欄にすると、現在の場所メモを削除する提案になります。',
          ),
        ),
        const SizedBox(height: V2Spacing.sm),
        _FieldCard(
          title: '設置場所',
          child: DropdownButtonHideUnderline(
            child: DropdownButton<InstallationType>(
              key: const Key('machineCorrectionInstallationType'),
              isExpanded: true,
              value: _selectedInstallationType,
              items: InstallationType.values
                  .map(
                    (type) => DropdownMenuItem<InstallationType>(
                      value: type,
                      child: Text(_installationLabel(type)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedInstallationType = value;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: V2Spacing.lg),
        FilledButton.icon(
          key: const Key('machineCorrectionReviewButton'),
          onPressed: widget.onReviewPressed == null
              ? null
              : () => _review(data),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('修正内容を確認'),
        ),
      ],
    );
  }

  void _ensureInitialized(VendingMachineDetailData data) {
    if (_initializedMachineId == data.machine.id) {
      return;
    }

    _initializedMachineId = data.machine.id;
    _nameController.text = data.machine.name;
    _placeController.text = data.machine.placeDescription ?? '';
    _selectedManufacturerValue =
        data.machine.manufacturerId?.value ?? _unknownManufacturerValue;
    _selectedLocation = data.machine.location;
    _selectedInstallationType = data.machine.installationType;
  }

  Future<void> _chooseLocation() async {
    final current = _selectedLocation;
    if (current == null) {
      return;
    }

    final picker = widget.positionPicker;
    GeoCoordinate? selected;

    if (picker != null) {
      selected = await picker(context, current);
    } else {
      selected = await V2MachineCorrectionPositionSheet.show(
        context,
        initialLocation: current,
      );
    }

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedLocation = selected;
    });
  }

  void _review(VendingMachineDetailData data) {
    final proposedName = _nameController.text.trim();

    if (proposedName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('名前を入力してください。')));
      return;
    }

    final proposedLocation = _selectedLocation;
    if (proposedLocation == null) {
      return;
    }

    ManufacturerId? proposedManufacturerId;

    if (_selectedManufacturerValue != _unknownManufacturerValue) {
      proposedManufacturerId = ManufacturerId.tryParse(
        _selectedManufacturerValue,
      );

      if (proposedManufacturerId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('メーカーを選び直してください。')));
        return;
      }
    }

    final draft = MachineCorrectionDraftBuilder.build(
      machineId: data.machine.id,
      currentName: data.machine.name,
      currentManufacturerId: data.machine.manufacturerId,
      currentLocation: data.machine.location,
      currentPlaceDescription: data.machine.placeDescription,
      currentInstallationType: data.machine.installationType,
      proposedName: proposedName,
      proposedManufacturerId: proposedManufacturerId,
      proposedLocation: proposedLocation,
      proposedPlaceDescription: _placeController.text,
      proposedInstallationType: _selectedInstallationType,
    );

    if (!draft.hasChanges) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('現在の情報から変更された項目がありません。')));
      return;
    }

    ref.read(machineCorrectionControllerProvider.notifier).begin(draft);
    widget.onReviewPressed?.call();
  }

  static String _installationLabel(InstallationType type) {
    return switch (type) {
      InstallationType.outdoor => '屋外',
      InstallationType.indoor => '屋内',
      InstallationType.unknown => '不明',
    };
  }
}

class _ManufacturerField extends ConsumerWidget {
  const _ManufacturerField({
    required this.currentManufacturerId,
    required this.currentManufacturerName,
    required this.selectedValue,
    required this.unknownValue,
    required this.onChanged,
  });

  final ManufacturerId? currentManufacturerId;
  final String currentManufacturerName;
  final String selectedValue;
  final String unknownValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncManufacturers = ref.watch(
      machineCorrectionManufacturersProvider,
    );

    return asyncManufacturers.when(
      loading: () => _buildDropdown(
        context,
        manufacturers: const <Manufacturer>[],
        isLoading: true,
      ),
      error: (_, _) => _buildDropdown(
        context,
        manufacturers: const <Manufacturer>[],
        isLoading: false,
      ),
      data: (result) => result.fold(
        onSuccess: (manufacturers) => _buildDropdown(
          context,
          manufacturers: manufacturers,
          isLoading: false,
        ),
        onFailure: (_) => _buildDropdown(
          context,
          manufacturers: const <Manufacturer>[],
          isLoading: false,
        ),
      ),
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required List<Manufacturer> manufacturers,
    required bool isLoading,
  }) {
    final labels = <String, String>{
      unknownValue: 'メーカー不明',
      if (currentManufacturerId != null)
        currentManufacturerId!.value: currentManufacturerName,
      for (final manufacturer in manufacturers)
        if (manufacturer.isSelectable)
          manufacturer.id.value: manufacturer.displayShortName,
    };

    if (!labels.containsKey(selectedValue)) {
      labels[selectedValue] = selectedValue;
    }

    return _FieldCard(
      title: 'メーカー',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('machineCorrectionManufacturer'),
              isExpanded: true,
              value: selectedValue,
              items: labels.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onChanged,
            ),
          ),
          if (isLoading) ...<Widget>[
            const SizedBox(height: V2Spacing.xs),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: V2Radius.card,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: V2Spacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}
