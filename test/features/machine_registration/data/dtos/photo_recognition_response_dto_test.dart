import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/machine_registration/data/dtos/photo_recognition_response_dto.dart';
import 'package:vending_app/features/machine_registration/domain/entities/photo_recognition_result.dart';

void main() {
  test('parses completed normalized recognition response', () {
    final dto = PhotoRecognitionResponseDto.fromMap(<String, Object?>{
      'manufacturerCandidates': <Object?>[
        <String, Object?>{'manufacturerId': 'asahi'},
      ],
      'productCandidates': <Object?>[
        <String, Object?>{'productId': 'otsuka_pocari_sweat'},
        <String, Object?>{'productId': 'asahi_wonda_black'},
      ],
      'unresolvedLabels': <Object?>['WILKINSON LEMON'],
      'recognitionStatus': 'completed',
    });

    final domain = dto.toDomain();

    expect(domain.status, PhotoRecognitionStatus.completed);
    expect(domain.manufacturerCandidateIds.map((id) => id.value), <String>[
      'asahi',
    ]);
    expect(domain.productCandidateIds.map((id) => id.value), <String>[
      'otsuka_pocari_sweat',
      'asahi_wonda_black',
    ]);
    expect(domain.unresolvedLabels, <String>['WILKINSON LEMON']);
  });

  test('rejects unexpected response fields', () {
    expect(
      () => PhotoRecognitionResponseDto.fromMap(<String, Object?>{
        'manufacturerCandidates': <Object?>[],
        'productCandidates': <Object?>[],
        'unresolvedLabels': <Object?>[],
        'recognitionStatus': 'completed',
        'rawAiOutput': 'must not reach client contract',
      }),
      throwsFormatException,
    );
  });
}
