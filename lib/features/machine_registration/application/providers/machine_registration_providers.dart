import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/photo_recognition_repository_impl.dart';
import '../../data/sources/callable_photo_recognition_data_source.dart';
import '../../data/sources/photo_recognition_data_source.dart';
import '../../domain/repositories/photo_recognition_repository.dart';
import '../../domain/services/recognition_request_id_generator.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/machine_registration_repository_impl.dart';
import '../../data/services/image_registration_photo_normalizer.dart';
import '../../data/sources/firebase_temporary_registration_photo_uploader.dart';
import '../../data/sources/image_picker_registration_photo_capture_source.dart';
import '../../data/sources/callable_machine_registration_data_source.dart';
import '../../data/sources/machine_registration_data_source.dart';
import '../../domain/repositories/machine_registration_repository.dart';
import '../../domain/services/photo_upload_id_generator.dart';
import '../../domain/services/registration_photo_capture_source.dart';
import '../../domain/services/registration_photo_normalizer.dart';
import '../../domain/services/temporary_registration_photo_uploader.dart';
import '../../domain/services/registration_request_id_generator.dart';

final machineRegistrationDataSourceProvider =
    Provider<MachineRegistrationDataSource>(
      (ref) => CallableMachineRegistrationDataSource(
        ref.watch(cloudFunctionsProvider),
      ),
      name: 'machineRegistrationDataSourceProvider',
    );

final machineRegistrationRepositoryProvider =
    Provider<MachineRegistrationRepository>(
      (ref) => MachineRegistrationRepositoryImpl(
        ref.watch(machineRegistrationDataSourceProvider),
      ),
      name: 'machineRegistrationRepositoryProvider',
    );

final registrationRequestIdGeneratorProvider =
    Provider<RegistrationRequestIdGenerator>(
      (_) => RegistrationRequestIdGenerator(),
      name: 'registrationRequestIdGeneratorProvider',
    );

final registrationPhotoCaptureSourceProvider =
    Provider<RegistrationPhotoCaptureSource>(
      (_) => ImagePickerRegistrationPhotoCaptureSource(),
      name: 'registrationPhotoCaptureSourceProvider',
    );

final registrationPhotoNormalizerProvider =
    Provider<RegistrationPhotoNormalizer>(
      (_) => const ImageRegistrationPhotoNormalizer(),
      name: 'registrationPhotoNormalizerProvider',
    );

final temporaryRegistrationPhotoUploaderProvider =
    Provider<TemporaryRegistrationPhotoUploader>(
      (ref) => FirebaseTemporaryRegistrationPhotoUploader(
        auth: ref.watch(firebaseAuthProvider),
        storage: ref.watch(firebaseStorageProvider),
      ),
      name: 'temporaryRegistrationPhotoUploaderProvider',
    );

final photoUploadIdGeneratorProvider = Provider<PhotoUploadIdGenerator>(
  (_) => PhotoUploadIdGenerator(),
  name: 'photoUploadIdGeneratorProvider',
);

final photoRecognitionDataSourceProvider = Provider<PhotoRecognitionDataSource>(
  (ref) =>
      CallablePhotoRecognitionDataSource(ref.watch(cloudFunctionsProvider)),
  name: 'photoRecognitionDataSourceProvider',
);

final photoRecognitionRepositoryProvider = Provider<PhotoRecognitionRepository>(
  (ref) => PhotoRecognitionRepositoryImpl(
    ref.watch(photoRecognitionDataSourceProvider),
  ),
  name: 'photoRecognitionRepositoryProvider',
);

final recognitionRequestIdGeneratorProvider =
    Provider<RecognitionRequestIdGenerator>(
      (_) => RecognitionRequestIdGenerator(),
      name: 'recognitionRequestIdGeneratorProvider',
    );
