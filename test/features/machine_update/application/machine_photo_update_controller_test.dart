import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/core/result/app_result.dart';
import '../../../../lib/features/machine_registration/application/providers/machine_registration_providers.dart';
import '../../../../lib/features/machine_registration/domain/entities/photo_recognition_result.dart';
import '../../../../lib/features/machine_registration/domain/models/normalized_registration_photo.dart';
import '../../../../lib/features/machine_registration/domain/models/temporary_registration_photo_upload.dart';
import '../../../../lib/features/machine_registration/domain/repositories/photo_recognition_repository.dart';
import '../../../../lib/features/machine_registration/domain/services/registration_photo_capture_source.dart';
import '../../../../lib/features/machine_registration/domain/services/registration_photo_normalizer.dart';
import '../../../../lib/features/machine_registration/domain/services/temporary_registration_photo_uploader.dart';
import '../../../../lib/features/machine_update/application/machine_photo_update_controller.dart';
import '../../../../lib/features/machine_update/application/machine_photo_update_state.dart';
import '../../../../lib/features/product_master/application/providers/product_master_providers.dart';
import '../../../../lib/features/product_master/domain/entities/product.dart';
import '../../../../lib/features/product_master/domain/repositories/product_repository.dart';
import '../../../../lib/features/product_master/domain/value_objects/master_id.dart';

void main() {
  final activeProduct = Product(
    id: ProductId.tryParse('asahi_calpis')!,
    name: 'カルピス',
    manufacturerId: ManufacturerId.tryParse('asahi')!,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  final otherProduct = Product(
    id: ProductId.tryParse('asahi_wonda_black')!,
    name: 'ワンダ ブラック',
    manufacturerId: ManufacturerId.tryParse('asahi')!,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  test('camera cancellation returns to idle', () async {
    final container = ProviderContainer(
      overrides: [
        registrationPhotoCaptureSourceProvider.overrideWithValue(
          _CaptureSource(null),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(machinePhotoUpdateControllerProvider.notifier)
        .captureAndRecognize();

    expect(result, isFalse);
    expect(
      container.read(machinePhotoUpdateControllerProvider).stage,
      MachinePhotoUpdateStage.idle,
    );
  });

  test(
    'capture upload recognition and Product Master resolution complete',
    () async {
      final photoRepository = _PhotoRecognitionRepository(
        <AppResult<PhotoRecognitionResult>>[
          AppResult<PhotoRecognitionResult>.success(
            PhotoRecognitionResult(
              manufacturerCandidateIds: const <ManufacturerId>[],
              productCandidateIds: <ProductId>[
                activeProduct.id,
                ProductId.tryParse('unknown_product')!,
              ],
              unresolvedLabels: const <String>['マスタ未登録の商品'],
              status: PhotoRecognitionStatus.completed,
            ),
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          registrationPhotoCaptureSourceProvider.overrideWithValue(
            _CaptureSource(Uint8List.fromList(<int>[9, 8, 7])),
          ),
          registrationPhotoNormalizerProvider.overrideWithValue(
            _PhotoNormalizer(),
          ),
          temporaryRegistrationPhotoUploaderProvider.overrideWithValue(
            _PhotoUploader(),
          ),
          photoRecognitionRepositoryProvider.overrideWithValue(photoRepository),
          productRepositoryProvider.overrideWithValue(
            _ProductRepository(<Product>[activeProduct, otherProduct]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final success = await container
          .read(machinePhotoUpdateControllerProvider.notifier)
          .captureAndRecognize();

      final state = container.read(machinePhotoUpdateControllerProvider);

      expect(success, isTrue);
      expect(state.stage, MachinePhotoUpdateStage.ready);
      expect(state.uploadId, _PhotoUploader.uploadId);
      expect(state.previewBytes, isNotNull);
      expect(state.products, hasLength(2));
      expect(state.aiProductCandidateIds, <String>['asahi_calpis']);
      expect(state.selectedProductIds, <String>{'asahi_calpis'});
      expect(state.unresolvedLabels, <String>['マスタ未登録の商品']);
      expect(photoRepository.callCount, 1);
    },
  );

  test('recognition failure preserves upload for reanalysis', () async {
    final repository = _PhotoRecognitionRepository(
      <AppResult<PhotoRecognitionResult>>[
        AppResult<PhotoRecognitionResult>.success(
          const PhotoRecognitionResult(
            manufacturerCandidateIds: <ManufacturerId>[],
            productCandidateIds: <ProductId>[],
            unresolvedLabels: <String>[],
            status: PhotoRecognitionStatus.failed,
          ),
        ),
        AppResult<PhotoRecognitionResult>.success(
          PhotoRecognitionResult(
            manufacturerCandidateIds: const <ManufacturerId>[],
            productCandidateIds: <ProductId>[activeProduct.id],
            unresolvedLabels: const <String>[],
            status: PhotoRecognitionStatus.completed,
          ),
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        registrationPhotoCaptureSourceProvider.overrideWithValue(
          _CaptureSource(Uint8List.fromList(<int>[1, 2, 3])),
        ),
        registrationPhotoNormalizerProvider.overrideWithValue(
          _PhotoNormalizer(),
        ),
        temporaryRegistrationPhotoUploaderProvider.overrideWithValue(
          _PhotoUploader(),
        ),
        photoRecognitionRepositoryProvider.overrideWithValue(repository),
        productRepositoryProvider.overrideWithValue(
          _ProductRepository(<Product>[activeProduct]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      machinePhotoUpdateControllerProvider.notifier,
    );

    final first = await controller.captureAndRecognize();
    final failedState = container.read(machinePhotoUpdateControllerProvider);

    expect(first, isFalse);
    expect(failedState.stage, MachinePhotoUpdateStage.failed);
    expect(failedState.uploadId, _PhotoUploader.uploadId);
    expect(failedState.previewBytes, isNotNull);
    expect(failedState.canRetryRecognition, isTrue);

    final retry = await controller.reanalyze();
    final readyState = container.read(machinePhotoUpdateControllerProvider);

    expect(retry, isTrue);
    expect(readyState.stage, MachinePhotoUpdateStage.ready);
    expect(readyState.selectedProductIds, <String>{'asahi_calpis'});
    expect(repository.callCount, 2);
  });

  test('selection accepts only loaded Product Master IDs', () async {
    final container = ProviderContainer(
      overrides: [
        registrationPhotoCaptureSourceProvider.overrideWithValue(
          _CaptureSource(Uint8List.fromList(<int>[1])),
        ),
        registrationPhotoNormalizerProvider.overrideWithValue(
          _PhotoNormalizer(),
        ),
        temporaryRegistrationPhotoUploaderProvider.overrideWithValue(
          _PhotoUploader(),
        ),
        photoRecognitionRepositoryProvider.overrideWithValue(
          _PhotoRecognitionRepository(<AppResult<PhotoRecognitionResult>>[
            AppResult<PhotoRecognitionResult>.success(
              PhotoRecognitionResult(
                manufacturerCandidateIds: const <ManufacturerId>[],
                productCandidateIds: <ProductId>[activeProduct.id],
                unresolvedLabels: const <String>[],
                status: PhotoRecognitionStatus.completed,
              ),
            ),
          ]),
        ),
        productRepositoryProvider.overrideWithValue(
          _ProductRepository(<Product>[activeProduct, otherProduct]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      machinePhotoUpdateControllerProvider.notifier,
    );

    await controller.captureAndRecognize();

    controller.replaceSelectedProducts(<String>{
      'asahi_wonda_black',
      'not_in_master',
    });

    expect(
      container.read(machinePhotoUpdateControllerProvider).selectedProductIds,
      <String>{'asahi_wonda_black'},
    );
  });

  test('reset clears completed state', () async {
    final container = ProviderContainer(
      overrides: [
        registrationPhotoCaptureSourceProvider.overrideWithValue(
          _CaptureSource(Uint8List.fromList(<int>[1])),
        ),
        registrationPhotoNormalizerProvider.overrideWithValue(
          _PhotoNormalizer(),
        ),
        temporaryRegistrationPhotoUploaderProvider.overrideWithValue(
          _PhotoUploader(),
        ),
        photoRecognitionRepositoryProvider.overrideWithValue(
          _PhotoRecognitionRepository(<AppResult<PhotoRecognitionResult>>[
            AppResult<PhotoRecognitionResult>.success(
              PhotoRecognitionResult(
                manufacturerCandidateIds: const <ManufacturerId>[],
                productCandidateIds: <ProductId>[activeProduct.id],
                unresolvedLabels: const <String>[],
                status: PhotoRecognitionStatus.completed,
              ),
            ),
          ]),
        ),
        productRepositoryProvider.overrideWithValue(
          _ProductRepository(<Product>[activeProduct]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      machinePhotoUpdateControllerProvider.notifier,
    );

    await controller.captureAndRecognize();
    controller.reset();

    expect(
      container.read(machinePhotoUpdateControllerProvider),
      isA<MachinePhotoUpdateState>()
          .having((state) => state.stage, 'stage', MachinePhotoUpdateStage.idle)
          .having((state) => state.uploadId, 'uploadId', isNull),
    );
  });
}

final class _CaptureSource implements RegistrationPhotoCaptureSource {
  const _CaptureSource(this.bytes);

  final Uint8List? bytes;

  @override
  Future<Uint8List?> capture() async => bytes;
}

final class _PhotoNormalizer implements RegistrationPhotoNormalizer {
  @override
  Future<NormalizedRegistrationPhoto> normalize(Uint8List sourceBytes) async {
    return NormalizedRegistrationPhoto(
      bytes: Uint8List.fromList(<int>[4, 5, 6]),
      width: 100,
      height: 100,
    );
  }
}

final class _PhotoUploader implements TemporaryRegistrationPhotoUploader {
  static const String uploadId = '123e4567-e89b-42d3-a456-426614174000';

  @override
  Future<TemporaryRegistrationPhotoUpload> upload({
    required String uploadId,
    required Uint8List jpegBytes,
  }) async {
    return TemporaryRegistrationPhotoUpload(
      uploadId: _PhotoUploader.uploadId,
      objectPath:
          'machine_uploads/user/${_PhotoUploader.uploadId}/original.jpg',
    );
  }
}

final class _PhotoRecognitionRepository implements PhotoRecognitionRepository {
  _PhotoRecognitionRepository(this.results);

  final List<AppResult<PhotoRecognitionResult>> results;

  int callCount = 0;

  @override
  Future<AppResult<PhotoRecognitionResult>> recognize({
    required String recognitionRequestId,
    required String uploadId,
  }) async {
    final index = callCount;
    callCount += 1;

    if (index >= results.length) {
      return results.last;
    }

    return results[index];
  }
}

final class _ProductRepository implements ProductRepository {
  const _ProductRepository(this.products);

  final List<Product> products;

  @override
  Future<AppResult<Product>> getProduct(ProductId id) async {
    for (final product in products) {
      if (product.id.value == id.value) {
        return AppResult<Product>.success(product);
      }
    }

    throw StateError('Test Product not found: ${id.value}');
  }

  @override
  Future<AppResult<List<Product>>> getProducts({bool activeOnly = true}) async {
    final values = activeOnly
        ? products.where((product) => product.isActive).toList(growable: false)
        : products;

    return AppResult<List<Product>>.success(values);
  }
}
