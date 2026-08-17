import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/core/errors/app_failure.dart';
import '../../../../lib/core/result/app_result.dart';
import '../../../../lib/features/machine_update/application/machine_photo_update_submit_controller.dart';
import '../../../../lib/features/machine_update/application/machine_photo_update_submit_state.dart';
import '../../../../lib/features/machine_update/application/providers/machine_photo_update_submit_providers.dart';
import '../../../../lib/features/machine_update/application/providers/machine_product_update_providers.dart';
import '../../../../lib/features/machine_update/domain/models/machine_photo_finalization_result.dart';
import '../../../../lib/features/machine_update/domain/models/machine_product_update_draft.dart';
import '../../../../lib/features/machine_update/domain/models/machine_product_update_operation.dart';
import '../../../../lib/features/machine_update/domain/models/machine_product_update_result.dart';
import '../../../../lib/features/machine_update/domain/repositories/machine_photo_finalization_repository.dart';
import '../../../../lib/features/machine_update/domain/repositories/machine_product_update_repository.dart';
import '../../../../lib/features/machine_update/domain/services/machine_product_update_request_id_generator.dart';
import '../../../../lib/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  const productRequestId = '11111111-1111-4111-8111-111111111111';
  const photoRequestId = '22222222-2222-4222-8222-222222222222';

  final machineId = VendingMachineId.tryParse('machine_001')!;

  test('product update completes before formal photo saving', () async {
    final events = <String>[];

    final productRepository = _ProductRepository(
      machineId: machineId,
      events: events,
    );

    final photoRepository = _PhotoRepository(
      machineId: machineId,
      events: events,
    );

    final container = ProviderContainer(
      overrides: [
        machineProductUpdateRepositoryProvider.overrideWithValue(
          productRepository,
        ),
        machinePhotoFinalizationRepositoryProvider.overrideWithValue(
          photoRepository,
        ),
        machineProductUpdateRequestIdGeneratorProvider.overrideWithValue(
          const _RequestIdGenerator(productRequestId),
        ),
        machinePhotoFinalizationRequestIdGeneratorProvider.overrideWithValue(
          const _RequestIdGenerator(photoRequestId),
        ),
      ],
    );
    addTearDown(container.dispose);

    final submitted = await container
        .read(machinePhotoUpdateSubmitControllerProvider.notifier)
        .submit(_draft(machineId, withProductChange: true));

    expect(submitted, isTrue);
    expect(events, <String>['product', 'photo']);

    final state = container.read(machinePhotoUpdateSubmitControllerProvider);

    expect(state.productCompleted, isTrue);
    expect(state.photoCompleted, isTrue);
    expect(state.stage, MachinePhotoUpdateSubmitStage.completed);
    expect(productRepository.requestIds, <String>[productRequestId]);
    expect(photoRepository.requestIds, <String>[photoRequestId]);
  });

  test(
    'zero product operations skips product update and saves photo',
    () async {
      final events = <String>[];

      final productRepository = _ProductRepository(
        machineId: machineId,
        events: events,
      );

      final photoRepository = _PhotoRepository(
        machineId: machineId,
        events: events,
      );

      final container = ProviderContainer(
        overrides: [
          machineProductUpdateRepositoryProvider.overrideWithValue(
            productRepository,
          ),
          machinePhotoFinalizationRepositoryProvider.overrideWithValue(
            photoRepository,
          ),
          machineProductUpdateRequestIdGeneratorProvider.overrideWithValue(
            const _RequestIdGenerator(productRequestId),
          ),
          machinePhotoFinalizationRequestIdGeneratorProvider.overrideWithValue(
            const _RequestIdGenerator(photoRequestId),
          ),
        ],
      );
      addTearDown(container.dispose);

      final submitted = await container
          .read(machinePhotoUpdateSubmitControllerProvider.notifier)
          .submit(_draft(machineId, withProductChange: false));

      expect(submitted, isTrue);
      expect(events, <String>['photo']);
      expect(productRepository.callCount, 0);
      expect(photoRepository.callCount, 1);
    },
  );

  test(
    'photo failure after product success retries only photo with same requestId',
    () async {
      final events = <String>[];

      final productRepository = _ProductRepository(
        machineId: machineId,
        events: events,
      );

      final photoRepository = _PhotoRepository(
        machineId: machineId,
        events: events,
        results: <AppResult<MachinePhotoFinalizationResult>>[
          const AppResult<MachinePhotoFinalizationResult>.failure(
            NetworkFailure(),
          ),
          AppResult<MachinePhotoFinalizationResult>.success(
            MachinePhotoFinalizationResult(
              machineId: machineId,
              photoId: 'p_test',
              added: true,
              primaryPhotoChanged: false,
            ),
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          machineProductUpdateRepositoryProvider.overrideWithValue(
            productRepository,
          ),
          machinePhotoFinalizationRepositoryProvider.overrideWithValue(
            photoRepository,
          ),
          machineProductUpdateRequestIdGeneratorProvider.overrideWithValue(
            const _RequestIdGenerator(productRequestId),
          ),
          machinePhotoFinalizationRequestIdGeneratorProvider.overrideWithValue(
            const _RequestIdGenerator(photoRequestId),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        machinePhotoUpdateSubmitControllerProvider.notifier,
      );

      final draft = _draft(machineId, withProductChange: true);

      expect(await controller.submit(draft), isFalse);

      var state = container.read(machinePhotoUpdateSubmitControllerProvider);

      expect(state.productCompleted, isTrue);
      expect(state.photoCompleted, isFalse);
      expect(productRepository.callCount, 1);
      expect(photoRepository.callCount, 1);

      expect(await controller.submit(draft), isTrue);

      state = container.read(machinePhotoUpdateSubmitControllerProvider);

      expect(state.isCompleted, isTrue);
      expect(productRepository.callCount, 1);
      expect(photoRepository.callCount, 2);
      expect(photoRepository.requestIds, <String>[
        photoRequestId,
        photoRequestId,
      ]);
      expect(events, <String>['product', 'photo', 'photo']);
    },
  );

  test(
    'product failure retries product with same requestId before photo',
    () async {
      final events = <String>[];

      final productRepository = _ProductRepository(
        machineId: machineId,
        events: events,
        results: <AppResult<MachineProductUpdateResult>>[
          const AppResult<MachineProductUpdateResult>.failure(NetworkFailure()),
          AppResult<MachineProductUpdateResult>.success(
            MachineProductUpdateResult(
              machineId: machineId,
              updated: true,
              changedProductIds: const <String>['product_001'],
            ),
          ),
        ],
      );

      final photoRepository = _PhotoRepository(
        machineId: machineId,
        events: events,
      );

      final container = ProviderContainer(
        overrides: [
          machineProductUpdateRepositoryProvider.overrideWithValue(
            productRepository,
          ),
          machinePhotoFinalizationRepositoryProvider.overrideWithValue(
            photoRepository,
          ),
          machineProductUpdateRequestIdGeneratorProvider.overrideWithValue(
            const _RequestIdGenerator(productRequestId),
          ),
          machinePhotoFinalizationRequestIdGeneratorProvider.overrideWithValue(
            const _RequestIdGenerator(photoRequestId),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        machinePhotoUpdateSubmitControllerProvider.notifier,
      );

      final draft = _draft(machineId, withProductChange: true);

      expect(await controller.submit(draft), isFalse);
      expect(productRepository.callCount, 1);
      expect(photoRepository.callCount, 0);

      expect(await controller.submit(draft), isTrue);

      expect(productRepository.callCount, 2);
      expect(photoRepository.callCount, 1);
      expect(productRepository.requestIds, <String>[
        productRequestId,
        productRequestId,
      ]);
      expect(events, <String>['product', 'product', 'photo']);
    },
  );
}

MachineProductUpdateDraft _draft(
  VendingMachineId machineId, {
  required bool withProductChange,
}) {
  return MachineProductUpdateDraft(
    machineId: machineId,
    operations: withProductChange
        ? <MachineProductUpdateOperation>[
            MachineProductUpdateOperation.addConfirmed(
              productId: 'product_001',
              source: MachineProductUpdateSource.photo,
            ),
          ]
        : const <MachineProductUpdateOperation>[],
    temporaryPhotoUploadId: '33333333-3333-4333-8333-333333333333',
  );
}

final class _ProductRepository implements MachineProductUpdateRepository {
  _ProductRepository({
    required this.machineId,
    required this.events,
    List<AppResult<MachineProductUpdateResult>>? results,
  }) : results =
           results ??
           <AppResult<MachineProductUpdateResult>>[
             AppResult<MachineProductUpdateResult>.success(
               MachineProductUpdateResult(
                 machineId: machineId,
                 updated: true,
                 changedProductIds: const <String>['product_001'],
               ),
             ),
           ];

  final VendingMachineId machineId;
  final List<String> events;
  final List<AppResult<MachineProductUpdateResult>> results;
  final List<String> requestIds = <String>[];

  int callCount = 0;

  @override
  Future<AppResult<MachineProductUpdateResult>> updateProducts({
    required String requestId,
    required MachineProductUpdateDraft draft,
  }) async {
    events.add('product');
    requestIds.add(requestId);

    final index = callCount;
    callCount += 1;

    return results[index < results.length ? index : results.length - 1];
  }
}

final class _PhotoRepository implements MachinePhotoFinalizationRepository {
  _PhotoRepository({
    required this.machineId,
    required this.events,
    List<AppResult<MachinePhotoFinalizationResult>>? results,
  }) : results =
           results ??
           <AppResult<MachinePhotoFinalizationResult>>[
             AppResult<MachinePhotoFinalizationResult>.success(
               MachinePhotoFinalizationResult(
                 machineId: machineId,
                 photoId: 'p_test',
                 added: true,
                 primaryPhotoChanged: false,
               ),
             ),
           ];

  final VendingMachineId machineId;
  final List<String> events;
  final List<AppResult<MachinePhotoFinalizationResult>> results;
  final List<String> requestIds = <String>[];

  int callCount = 0;

  @override
  Future<AppResult<MachinePhotoFinalizationResult>> addPhoto({
    required String requestId,
    required VendingMachineId machineId,
    required String temporaryPhotoUploadId,
  }) async {
    events.add('photo');
    requestIds.add(requestId);

    final index = callCount;
    callCount += 1;

    return results[index < results.length ? index : results.length - 1];
  }
}

final class _RequestIdGenerator
    implements MachineProductUpdateRequestIdGenerator {
  const _RequestIdGenerator(this.value);

  final String value;

  @override
  String next() => value;
}
