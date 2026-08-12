import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home_map/application/providers/vending_machine_map_providers.dart';
import '../../domain/services/registration_duplicate_search_service.dart';

final registrationDuplicateSearchServiceProvider =
    Provider<RegistrationDuplicateSearchService>(
      (ref) => RegistrationDuplicateSearchService(
        ref.watch(vendingMachineMapRepositoryProvider),
      ),
      name: 'registrationDuplicateSearchServiceProvider',
    );
