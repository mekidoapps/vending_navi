import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../product_master/domain/entities/manufacturer.dart';
import '../../product_master/domain/entities/product.dart';
import '../application/machine_registration_controller.dart';
import '../application/registration_photo_recognition_controller.dart';
import '../application/registration_photo_recognition_state.dart';
import 'v2_registration_home_action.dart';

class V2RegistrationPhotoCandidatesScreen extends ConsumerStatefulWidget {
  const V2RegistrationPhotoCandidatesScreen({
    super.key,
    this.onRetake,
    this.onManufacturerFallback,
    this.onLocationOnlyFallback,
    this.onConfirmed,
  });

  final VoidCallback? onRetake;
  final VoidCallback? onManufacturerFallback;
  final VoidCallback? onLocationOnlyFallback;
  final VoidCallback? onConfirmed;

  @override
  ConsumerState<V2RegistrationPhotoCandidatesScreen> createState() =>
      _V2RegistrationPhotoCandidatesScreenState();
}

class _V2RegistrationPhotoCandidatesScreenState
    extends ConsumerState<V2RegistrationPhotoCandidatesScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final uploadId = ref
          .read(machineRegistrationControllerProvider)
          .draft
          .temporaryPhotoUploadId;

      if (uploadId == null || uploadId.trim().isEmpty) {
        return;
      }

      ref
          .read(registrationPhotoRecognitionControllerProvider.notifier)
          .recognize(uploadId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationPhotoRecognitionControllerProvider);
    final uploadId = ref
        .watch(machineRegistrationControllerProvider)
        .draft
        .temporaryPhotoUploadId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI候補を確認'),
        actions: V2RegistrationHomeAction.appBarActions(context, ref),
      ),
      body: SafeArea(
        child: switch (state.stage) {
          RegistrationPhotoRecognitionStage.idle => _IdleBody(
            hasUpload: uploadId != null && uploadId.trim().isNotEmpty,
          ),
          RegistrationPhotoRecognitionStage.loading =>
            const _RecognitionLoadingBody(),
          RegistrationPhotoRecognitionStage.failed => _RecognitionFailureBody(
            message: state.failureMessage ?? '写真を認識できませんでした。',
            onRetry: state.uploadId == null
                ? null
                : () {
                    ref
                        .read(
                          registrationPhotoRecognitionControllerProvider
                              .notifier,
                        )
                        .reanalyze();
                  },
            onRetake: widget.onRetake,
            onManufacturerFallback: widget.onManufacturerFallback,
            onLocationOnlyFallback: widget.onLocationOnlyFallback,
          ),
          RegistrationPhotoRecognitionStage.ready => _CandidateBody(
            state: state,
            onChangeManufacturer: () => _showManufacturerPicker(state),
            onEditProducts: () => _showProductPicker(state),
            onSave: () => _saveCandidates(state),
          ),
        },
      ),
    );
  }

  Future<void> _showManufacturerPicker(
    RegistrationPhotoRecognitionState state,
  ) async {
    final controller = ref.read(
      registrationPhotoRecognitionControllerProvider.notifier,
    );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              V2Spacing.lg,
              0,
              V2Spacing.lg,
              V2Spacing.lg,
            ),
            children: <Widget>[
              Text(
                '自販機ブランドを選ぶ',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: V2Spacing.md),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('分からない・ブランド表示なし'),
                trailing: state.selectedManufacturerId == null
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  controller.selectManufacturer(null);
                  Navigator.of(sheetContext).pop();
                },
              ),
              for (final manufacturer in state.manufacturers)
                ListTile(
                  title: Text(manufacturer.displayShortName),
                  subtitle: manufacturer.name == manufacturer.displayShortName
                      ? null
                      : Text(manufacturer.name),
                  trailing:
                      state.selectedManufacturerId == manufacturer.id.value
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    controller.selectManufacturer(manufacturer.id.value);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showProductPicker(
    RegistrationPhotoRecognitionState state,
  ) async {
    var working = <String>{...state.selectedProductIds};

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.78,
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: V2Spacing.lg,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '商品を追加・変更',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop(working);
                            },
                            child: const Text('完了'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: state.products.length,
                        itemBuilder: (context, index) {
                          final product = state.products[index];
                          final selected = working.contains(product.id.value);
                          return CheckboxListTile(
                            value: selected,
                            title: Text(product.name),
                            subtitle: Text(
                              _manufacturerName(state.manufacturers, product),
                            ),
                            onChanged: (_) {
                              setSheetState(() {
                                if (!working.add(product.id.value)) {
                                  working.remove(product.id.value);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      ref
          .read(registrationPhotoRecognitionControllerProvider.notifier)
          .replaceSelectedProducts(result);
    }
  }

  void _saveCandidates(RegistrationPhotoRecognitionState state) {
    Manufacturer? selectedManufacturer;
    for (final manufacturer in state.manufacturers) {
      if (manufacturer.id.value == state.selectedManufacturerId) {
        selectedManufacturer = manufacturer;
        break;
      }
    }

    final selectedProducts = state.products
        .where((product) => state.selectedProductIds.contains(product.id.value))
        .toList(growable: false);

    ref
        .read(machineRegistrationControllerProvider.notifier)
        .applyPhotoRecognitionConfirmation(
          manufacturerId: selectedManufacturer?.id,
          productIds: selectedProducts
              .map((product) => product.id)
              .toList(growable: false),
        );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('AI候補の確認内容を保存しました')));

    widget.onConfirmed?.call();
  }

  static String _manufacturerName(
    List<Manufacturer> manufacturers,
    Product product,
  ) {
    for (final manufacturer in manufacturers) {
      if (manufacturer.id.value == product.manufacturerId.value) {
        return manufacturer.displayShortName;
      }
    }
    return product.manufacturerId.value;
  }
}

class _IdleBody extends StatelessWidget {
  const _IdleBody({required this.hasUpload});

  final bool hasUpload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.lg),
        child: Text(
          hasUpload ? '認識を開始しています…' : '認識する写真がありません。撮影画面へ戻ってください。',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _RecognitionLoadingBody extends StatelessWidget {
  const _RecognitionLoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(V2Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: V2Spacing.md),
            Text('写真から自販機ブランドと商品候補を探しています…'),
            SizedBox(height: V2Spacing.xs),
            Text('結果はこのあと確認・修正できます', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _RecognitionFailureBody extends StatelessWidget {
  const _RecognitionFailureBody({
    required this.message,
    required this.onRetry,
    required this.onRetake,
    required this.onManufacturerFallback,
    required this.onLocationOnlyFallback,
  });

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onRetake;
  final VoidCallback? onManufacturerFallback;
  final VoidCallback? onLocationOnlyFallback;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(V2Spacing.lg),
      children: <Widget>[
        Icon(
          Icons.image_search_outlined,
          size: 52,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: V2Spacing.md),
        Text(
          '写真から候補を見つけられませんでした',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: V2Spacing.xs),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: V2Spacing.lg),
        FilledButton(onPressed: onRetry, child: const Text('もう一度認識する')),
        const SizedBox(height: V2Spacing.xs),
        OutlinedButton(onPressed: onRetake, child: const Text('写真を撮り直す')),
        const SizedBox(height: V2Spacing.xs),
        OutlinedButton(
          onPressed: onManufacturerFallback,
          child: const Text('メーカーから登録する'),
        ),
        const SizedBox(height: V2Spacing.xs),
        TextButton(
          onPressed: onLocationOnlyFallback,
          child: const Text('ブランド不明のまま登録する'),
        ),
      ],
    );
  }
}

class _CandidateBody extends StatelessWidget {
  const _CandidateBody({
    required this.state,
    required this.onChangeManufacturer,
    required this.onEditProducts,
    required this.onSave,
  });

  final RegistrationPhotoRecognitionState state;
  final VoidCallback onChangeManufacturer;
  final VoidCallback onEditProducts;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final selectedManufacturer = _findManufacturer(
      state.manufacturers,
      state.selectedManufacturerId,
    );
    final selectedProducts = state.products
        .where((product) => state.selectedProductIds.contains(product.id.value))
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(V2Spacing.lg),
      children: <Widget>[
        Text(
          'AIが見つけた候補です',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: V2Spacing.xs),
        Text(
          '自動で確定はしません。実物と見比べて、違うところは変更してください。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: V2Spacing.lg),
        _SectionCard(
          title: '自販機ブランド',
          trailing: TextButton(
            onPressed: onChangeManufacturer,
            child: const Text('変更'),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selectedManufacturer == null
                    ? Icons.help_outline
                    : Icons.storefront_outlined,
              ),
              const SizedBox(width: V2Spacing.md),
              Expanded(
                child: Text(
                  selectedManufacturer?.displayShortName ?? '分からない・表示なし',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selectedManufacturer != null &&
                  state.aiManufacturerCandidateIds.contains(
                    selectedManufacturer.id.value,
                  ))
                const Chip(label: Text('AI候補')),
            ],
          ),
        ),
        const SizedBox(height: V2Spacing.md),
        _SectionCard(
          title: '商品',
          trailing: TextButton(
            onPressed: onEditProducts,
            child: const Text('追加・変更'),
          ),
          child: selectedProducts.isEmpty
              ? const Text('選択中の商品はありません')
              : Column(
                  children: <Widget>[
                    for (final product in selectedProducts)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(product.name),
                        subtitle: Text(
                          _manufacturerName(state.manufacturers, product),
                        ),
                        trailing:
                            state.aiProductCandidateIds.contains(
                              product.id.value,
                            )
                            ? const Chip(label: Text('AI候補'))
                            : const Chip(label: Text('手動追加')),
                      ),
                  ],
                ),
        ),
        if (state.unresolvedLabels.isNotEmpty) ...<Widget>[
          const SizedBox(height: V2Spacing.md),
          _SectionCard(
            title: 'まだ商品マスタと照合できなかった表示',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('写真には見えましたが、既存の商品IDへ安全に結び付けられなかったものです。'),
                const SizedBox(height: V2Spacing.md),
                Wrap(
                  spacing: V2Spacing.xs,
                  runSpacing: V2Spacing.xs,
                  children: <Widget>[
                    for (final label in state.unresolvedLabels)
                      Chip(label: Text(label)),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: V2Spacing.lg),
        FilledButton(
          key: const Key('registrationPhotoCandidatesSaveButton'),
          onPressed: onSave,
          child: const Text('この内容を保存'),
        ),
        const SizedBox(height: V2Spacing.xs),
        Text(
          'この段階ではAI候補を公開データへ保存しません。正式登録への接続は次の工程で行います。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  static Manufacturer? _findManufacturer(
    List<Manufacturer> manufacturers,
    String? id,
  ) {
    if (id == null) {
      return null;
    }
    for (final manufacturer in manufacturers) {
      if (manufacturer.id.value == id) {
        return manufacturer;
      }
    }
    return null;
  }

  static String _manufacturerName(
    List<Manufacturer> manufacturers,
    Product product,
  ) {
    for (final manufacturer in manufacturers) {
      if (manufacturer.id.value == product.manufacturerId.value) {
        return manufacturer.displayShortName;
      }
    }
    return product.manufacturerId.value;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.card),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: V2Spacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
