import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/result/app_result.dart';
import '../../domain/entities/manufacturer.dart';
import '../../domain/repositories/manufacturer_repository.dart';
import '../../domain/value_objects/master_id.dart';
import '../mappers/manufacturer_mapper.dart';
import '../sources/master_document.dart';
import '../sources/master_document_source.dart';

final class ManufacturerRepositoryImpl implements ManufacturerRepository {
  ManufacturerRepositoryImpl(this._source);

  final MasterDocumentSource _source;

  @override
  Future<AppResult<List<Manufacturer>>> getManufacturers({
    bool activeOnly = true,
  }) async {
    try {
      final documents = await _source.fetchCollection(
        MasterCollections.manufacturers,
      );
      final manufacturers = <Manufacturer>[];

      for (final document in documents) {
        final mapped = _mapDocument(document);
        final failure = mapped.failureOrNull;
        if (failure != null) {
          return AppResult<List<Manufacturer>>.failure(failure);
        }

        final manufacturer = mapped.valueOrNull;
        if (manufacturer == null) {
          return const AppResult<List<Manufacturer>>.failure(UnknownFailure());
        }

        if (!activeOnly || manufacturer.isActive) {
          manufacturers.add(manufacturer);
        }
      }

      manufacturers.sort((left, right) => left.name.compareTo(right.name));

      return AppResult<List<Manufacturer>>.success(
        List<Manufacturer>.unmodifiable(manufacturers),
      );
    } on Object catch (error) {
      return AppResult<List<Manufacturer>>.failure(FailureMapper.map(error));
    }
  }

  @override
  Future<AppResult<Manufacturer>> getManufacturer(ManufacturerId id) async {
    try {
      final document = await _source.fetchDocument(
        MasterCollections.manufacturers,
        id.value,
      );

      if (document == null) {
        return const AppResult<Manufacturer>.failure(NotFoundFailure());
      }

      return _mapDocument(document);
    } on Object catch (error) {
      return AppResult<Manufacturer>.failure(FailureMapper.map(error));
    }
  }

  AppResult<Manufacturer> _mapDocument(MasterDocument document) {
    return ManufacturerMapper.fromFirestoreDocument(
      documentId: document.id,
      data: document.data,
    );
  }
}
