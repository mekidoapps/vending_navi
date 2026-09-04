import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/v2_email_auth_screen.dart';
import '../../features/home_map/application/vending_machine_map_controller.dart';
import '../../features/home_map/presentation/v2_home_map_screen.dart';
import '../../features/machine_registration/application/machine_registration_controller.dart';
import '../../features/machine_registration/application/registration_photo_recognition_controller.dart';
import '../../features/machine_registration/presentation/v2_registration_confirmation_screen.dart';
import '../../features/machine_registration/presentation/v2_registration_duplicate_candidates_screen.dart';
import '../../features/machine_registration/presentation/v2_registration_manufacturer_screen.dart';
import '../../features/machine_registration/presentation/v2_registration_method_screen.dart';
import '../../features/machine_registration/presentation/v2_registration_photo_screen.dart';
import '../../features/machine_registration/presentation/v2_registration_photo_candidates_screen.dart';
import '../../features/machine_registration/presentation/v2_registration_position_screen.dart';
import '../../features/machine_registration/presentation/v2_registration_auth_gate.dart';
import '../../features/product_search/application/genre_machine_search_controller.dart';
import '../../features/product_search/application/genre_search_selection_controller.dart';
import '../../features/product_search/application/product_machine_search_controller.dart';
import '../../features/product_search/application/product_search_selection_controller.dart';
import '../../features/user_profile/presentation/v2_my_page_screen.dart';
import '../../features/vending_machine/domain/value_objects/vending_machine_id.dart';
import '../../features/machine_update/application/machine_correction_controller.dart';
import '../../features/machine_update/application/machine_report_controller.dart';
import '../../features/machine_update/application/machine_product_update_controller.dart';
import '../../features/machine_update/presentation/v2_product_update_confirmation_screen.dart';
import '../../features/vending_machine/application/providers/vending_machine_detail_providers.dart';
import '../../features/machine_update/presentation/v2_machine_update_menu_screen.dart';
import '../../features/machine_update/presentation/v2_machine_photo_update_screen.dart';
import '../../features/machine_update/presentation/v2_machine_photo_update_review_screen.dart';
import '../../features/machine_update/presentation/v2_machine_correction_confirmation_screen.dart';
import '../../features/machine_update/presentation/v2_machine_correction_screen.dart';
import '../../features/machine_update/presentation/v2_machine_report_confirmation_screen.dart';
import '../../features/machine_update/presentation/v2_machine_report_screen.dart';
import '../../features/machine_update/presentation/v2_manual_product_update_screen.dart';
import '../../features/vending_machine/presentation/v2_vending_machine_detail_screen.dart';
import '../../screens/startup_router_screen.dart';
import 'app_route.dart';
import 'entry_mode.dart';

typedef AppRouteWidgetBuilder = Widget Function(BuildContext context);
typedef AppMachineDetailWidgetBuilder =
    Widget Function(BuildContext context, VendingMachineId machineId);

GoRouter createAppRouter({
  required AppEntryMode entryMode,
  AppRouteWidgetBuilder? legacyBuilder,
  AppRouteWidgetBuilder? v2Builder,
  AppMachineDetailWidgetBuilder? machineDetailBuilder,
  AppMachineDetailWidgetBuilder? machineUpdateMenuBuilder,
  AppMachineDetailWidgetBuilder? photoProductUpdateBuilder,
  AppMachineDetailWidgetBuilder? photoProductUpdateConfirmationBuilder,
  AppMachineDetailWidgetBuilder? manualProductUpdateBuilder,
  AppMachineDetailWidgetBuilder? productUpdateConfirmationBuilder,
  AppMachineDetailWidgetBuilder? machineCorrectionBuilder,
  AppMachineDetailWidgetBuilder? machineCorrectionConfirmationBuilder,
  AppMachineDetailWidgetBuilder? machineReportBuilder,
  AppMachineDetailWidgetBuilder? machineReportConfirmationBuilder,
  AppRouteWidgetBuilder? emailAuthBuilder,
  AppRouteWidgetBuilder? myPageBuilder,
  AppRouteWidgetBuilder? registrationPositionBuilder,
  AppRouteWidgetBuilder? registrationDuplicatesBuilder,
  AppRouteWidgetBuilder? registrationMethodBuilder,
  AppRouteWidgetBuilder? registrationPhotoBuilder,
  AppRouteWidgetBuilder? registrationPhotoCandidatesBuilder,
  AppRouteWidgetBuilder? registrationManufacturerBuilder,
  AppRouteWidgetBuilder? registrationConfirmationBuilder,
}) {
  return GoRouter(
    initialLocation: entryMode.initialLocation,
    routes: <RouteBase>[
      GoRoute(
        name: AppRoute.legacyRoot.name,
        path: AppRoute.legacyRoot.path,
        builder: (BuildContext context, GoRouterState state) {
          return legacyBuilder?.call(context) ?? const StartupRouterScreen();
        },
      ),
      GoRoute(
        name: AppRoute.v2Foundation.name,
        path: AppRoute.v2Foundation.path,
        builder: (BuildContext context, GoRouterState state) {
          final override = v2Builder;
          if (override != null) {
            return override(context);
          }

          return Consumer(
            builder: (context, ref, _) {
              return V2HomeMapScreen(
                enableUserFeatures: true,
                onRegisterPressed: () {
                  ref
                      .read(machineRegistrationControllerProvider.notifier)
                      .reset();

                  context.pushNamed(AppRoute.v2RegistrationPosition.name);
                },
                onProfilePressed: () {
                  context.pushNamed(AppRoute.v2MyPage.name);
                },
              );
            },
          );
        },
      ),
      GoRoute(
        name: AppRoute.v2MachineDetail.name,
        path: AppRoute.v2MachineDetail.path,
        builder: (BuildContext context, GoRouterState state) {
          final rawMachineId = state.pathParameters['machineId'] ?? '';
          final machineId = VendingMachineId.tryParse(rawMachineId);

          if (machineId == null) {
            return RouteErrorScreen(location: state.uri.toString());
          }

          return machineDetailBuilder?.call(context, machineId) ??
              V2VendingMachineDetailScreen(machineId: machineId);
        },
      ),
      GoRoute(
        name: AppRoute.v2MachineUpdateMenu.name,
        path: AppRoute.v2MachineUpdateMenu.path,
        builder: (BuildContext context, GoRouterState state) {
          final rawMachineId = state.pathParameters['machineId'] ?? '';
          final machineId = VendingMachineId.tryParse(rawMachineId);

          if (machineId == null) {
            return RouteErrorScreen(location: state.uri.toString());
          }

          return machineUpdateMenuBuilder?.call(context, machineId) ??
              V2MachineUpdateMenuScreen(
                machineId: machineId,
                onManualProductUpdatePressed: () {
                  context.pushNamed(
                    AppRoute.v2ManualProductUpdate.name,
                    pathParameters: <String, String>{
                      'machineId': machineId.value,
                    },
                  );
                },
                onPhotoUpdatePressed: () {
                  context.pushNamed(
                    AppRoute.v2PhotoProductUpdate.name,
                    pathParameters: <String, String>{
                      'machineId': machineId.value,
                    },
                  );
                },
                onBasicInfoCorrectionPressed: () {
                  context.pushNamed(
                    AppRoute.v2MachineCorrection.name,
                    pathParameters: <String, String>{
                      'machineId': machineId.value,
                    },
                  );
                },
                onReportPressed: () {
                  context.pushNamed(
                    AppRoute.v2MachineReport.name,
                    pathParameters: <String, String>{
                      'machineId': machineId.value,
                    },
                  );
                },
              );
        },
      ),
      GoRoute(
        name: AppRoute.v2PhotoProductUpdate.name,
        path: AppRoute.v2PhotoProductUpdate.path,
        builder: (BuildContext context, GoRouterState state) {
          final rawMachineId = state.pathParameters['machineId'] ?? '';
          final machineId = VendingMachineId.tryParse(rawMachineId);

          if (machineId == null) {
            return RouteErrorScreen(location: state.uri.toString());
          }

          return photoProductUpdateBuilder?.call(context, machineId) ??
              V2MachinePhotoUpdateScreen(machineId: machineId);
        },
      ),
      GoRoute(
        name: AppRoute.v2PhotoProductUpdateConfirmation.name,
        path: AppRoute.v2PhotoProductUpdateConfirmation.path,
        builder: (BuildContext context, GoRouterState state) {
          final rawMachineId = state.pathParameters['machineId'] ?? '';
          final machineId = VendingMachineId.tryParse(rawMachineId);

          if (machineId == null) {
            return RouteErrorScreen(location: state.uri.toString());
          }

          return photoProductUpdateConfirmationBuilder?.call(
                context,
                machineId,
              ) ??
              V2MachinePhotoUpdateReviewScreen(
                machineId: machineId,
                onCompleted: () {
                  context.goNamed(
                    AppRoute.v2MachineDetail.name,
                    pathParameters: <String, String>{
                      'machineId': machineId.value,
                    },
                  );
                },
              );
        },
      ),
      GoRoute(
        name: AppRoute.v2ManualProductUpdate.name,
        path: AppRoute.v2ManualProductUpdate.path,
        builder: (BuildContext context, GoRouterState state) {
          final rawMachineId = state.pathParameters['machineId'] ?? '';
          final machineId = VendingMachineId.tryParse(rawMachineId);

          if (machineId == null) {
            return RouteErrorScreen(location: state.uri.toString());
          }

          return manualProductUpdateBuilder?.call(context, machineId) ??
              V2ManualProductUpdateScreen(
                machineId: machineId,
                onReviewPressed: () {
                  context.pushNamed(
                    AppRoute.v2ProductUpdateConfirmation.name,
                    pathParameters: <String, String>{
                      'machineId': machineId.value,
                    },
                  );
                },
              );
        },
      ),
      GoRoute(
        name: AppRoute.v2ProductUpdateConfirmation.name,
        path: AppRoute.v2ProductUpdateConfirmation.path,
        builder: (BuildContext context, GoRouterState state) {
          final rawMachineId = state.pathParameters['machineId'] ?? '';
          final machineId = VendingMachineId.tryParse(rawMachineId);

          if (machineId == null) {
            return RouteErrorScreen(location: state.uri.toString());
          }

          final override = productUpdateConfirmationBuilder;
          if (override != null) {
            return override(context, machineId);
          }

          return Consumer(
            builder: (context, ref, _) {
              return V2ProductUpdateConfirmationScreen(
                machineId: machineId,
                onCompleted: () {
                  ref.invalidate(vendingMachineDetailProvider(machineId));
                  ref
                      .read(machineProductUpdateControllerProvider.notifier)
                      .reset();

                  context.goNamed(
                    AppRoute.v2MachineDetail.name,
                    pathParameters: <String, String>{
                      'machineId': machineId.value,
                    },
                  );
                },
              );
            },
          );
        },
      ),
      GoRoute(
        name: AppRoute.v2MachineCorrection.name,
        path: AppRoute.v2MachineCorrection.path,
        builder: (BuildContext context, GoRouterState state) {
          final rawMachineId = state.pathParameters['machineId'] ?? '';
          final machineId = VendingMachineId.tryParse(rawMachineId);

          if (machineId == null) {
            return RouteErrorScreen(location: state.uri.toString());
          }

          return machineCorrectionBuilder?.call(context, machineId) ??
              V2MachineCorrectionScreen(
                machineId: machineId,
                onReviewPressed: () {
                  context.pushNamed(
                    AppRoute.v2MachineCorrectionConfirmation.name,
                    pathParameters: <String, String>{
                      'machineId': machineId.value,
                    },
                  );
                },
              );
        },
      ),
      GoRoute(
        name: AppRoute.v2MachineCorrectionConfirmation.name,
        path: AppRoute.v2MachineCorrectionConfirmation.path,
        builder: (BuildContext context, GoRouterState state) {
          final rawMachineId = state.pathParameters['machineId'] ?? '';
          final machineId = VendingMachineId.tryParse(rawMachineId);

          if (machineId == null) {
            return RouteErrorScreen(location: state.uri.toString());
          }

          final override = machineCorrectionConfirmationBuilder;
          if (override != null) {
            return override(context, machineId);
          }

          return Consumer(
            builder: (context, ref, _) {
              return V2MachineCorrectionConfirmationScreen(
                machineId: machineId,
                onCompleted: () {
                  ref
                      .read(machineCorrectionControllerProvider.notifier)
                      .reset();

                  context.goNamed(
                    AppRoute.v2MachineDetail.name,
                    pathParameters: <String, String>{
                      'machineId': machineId.value,
                    },
                  );
                },
              );
            },
          );
        },
      ),
      GoRoute(
        name: AppRoute.v2MachineReport.name,
        path: AppRoute.v2MachineReport.path,
        builder: (BuildContext context, GoRouterState state) {
          final rawMachineId = state.pathParameters['machineId'] ?? '';
          final machineId = VendingMachineId.tryParse(rawMachineId);

          if (machineId == null) {
            return RouteErrorScreen(location: state.uri.toString());
          }

          return machineReportBuilder?.call(context, machineId) ??
              V2MachineReportScreen(
                machineId: machineId,
                photoId: state.uri.queryParameters['photoId'],
                onReviewPressed: () {
                  context.pushNamed(
                    AppRoute.v2MachineReportConfirmation.name,
                    pathParameters: <String, String>{
                      'machineId': machineId.value,
                    },
                  );
                },
              );
        },
      ),
      GoRoute(
        name: AppRoute.v2MachineReportConfirmation.name,
        path: AppRoute.v2MachineReportConfirmation.path,
        builder: (BuildContext context, GoRouterState state) {
          final rawMachineId = state.pathParameters['machineId'] ?? '';
          final machineId = VendingMachineId.tryParse(rawMachineId);

          if (machineId == null) {
            return RouteErrorScreen(location: state.uri.toString());
          }

          final override = machineReportConfirmationBuilder;
          if (override != null) {
            return override(context, machineId);
          }

          return Consumer(
            builder: (context, ref, _) {
              return V2MachineReportConfirmationScreen(
                machineId: machineId,
                onCompleted: () {
                  ref.read(machineReportControllerProvider.notifier).reset();

                  context.goNamed(
                    AppRoute.v2MachineDetail.name,
                    pathParameters: <String, String>{
                      'machineId': machineId.value,
                    },
                  );
                },
              );
            },
          );
        },
      ),
      GoRoute(
        name: AppRoute.v2EmailAuth.name,
        path: AppRoute.v2EmailAuth.path,
        builder: (BuildContext context, GoRouterState state) {
          return emailAuthBuilder?.call(context) ?? const V2EmailAuthScreen();
        },
      ),
      GoRoute(
        name: AppRoute.v2MyPage.name,
        path: AppRoute.v2MyPage.path,
        builder: (BuildContext context, GoRouterState state) {
          return myPageBuilder?.call(context) ??
              const V2MyPageScreen(enableFavoriteProducts: true);
        },
      ),
      GoRoute(
        name: AppRoute.v2RegistrationPosition.name,
        path: AppRoute.v2RegistrationPosition.path,
        builder: (BuildContext context, GoRouterState state) {
          return registrationPositionBuilder?.call(context) ??
              V2RegistrationPositionScreen(
                onContinue: () {
                  context.pushNamed(AppRoute.v2RegistrationDuplicates.name);
                },
              );
        },
      ),
      GoRoute(
        name: AppRoute.v2RegistrationDuplicates.name,
        path: AppRoute.v2RegistrationDuplicates.path,
        builder: (BuildContext context, GoRouterState state) {
          return registrationDuplicatesBuilder?.call(context) ??
              V2RegistrationDuplicateCandidatesScreen(
                onContinue: () {
                  context.pushNamed(AppRoute.v2RegistrationMethod.name);
                },
                onViewCandidate: (machine) {
                  context.pushNamed(
                    AppRoute.v2MachineDetail.name,
                    pathParameters: <String, String>{
                      'machineId': machine.id.value,
                    },
                  );
                },
              );
        },
      ),
      GoRoute(
        name: AppRoute.v2RegistrationMethod.name,
        path: AppRoute.v2RegistrationMethod.path,
        builder: (BuildContext context, GoRouterState state) {
          return registrationMethodBuilder?.call(context) ??
              V2RegistrationMethodScreen(
                onPhotoSelected: () {
                  context.pushNamed(AppRoute.v2RegistrationPhoto.name);
                },
                onManufacturerSelected: () {
                  context.pushNamed(AppRoute.v2RegistrationManufacturer.name);
                },
              );
        },
      ),
      GoRoute(
        name: AppRoute.v2RegistrationPhoto.name,
        path: AppRoute.v2RegistrationPhoto.path,
        builder: (BuildContext context, GoRouterState state) {
          return registrationPhotoBuilder?.call(context) ??
              V2RegistrationPhotoScreen(
                onPhotoPrepared: () {
                  context.pushNamed(
                    AppRoute.v2RegistrationPhotoCandidates.name,
                  );
                },
              );
        },
      ),
      GoRoute(
        name: AppRoute.v2RegistrationPhotoCandidates.name,
        path: AppRoute.v2RegistrationPhotoCandidates.path,
        builder: (BuildContext context, GoRouterState state) {
          final override = registrationPhotoCandidatesBuilder;
          if (override != null) {
            return override(context);
          }

          return Consumer(
            builder: (context, ref, _) {
              return V2RegistrationPhotoCandidatesScreen(
                onRetake: () {
                  ref
                      .read(
                        registrationPhotoRecognitionControllerProvider.notifier,
                      )
                      .reset();
                  context.pop();
                },
                onManufacturerFallback: () {
                  ref
                      .read(machineRegistrationControllerProvider.notifier)
                      .chooseManufacturerMethod();
                  context.pushNamed(AppRoute.v2RegistrationManufacturer.name);
                },
                onLocationOnlyFallback: () {
                  ref
                      .read(machineRegistrationControllerProvider.notifier)
                      .chooseLocationOnly();
                  context.pushNamed(AppRoute.v2RegistrationConfirmation.name);
                },
                onConfirmed: () {
                  context.pushNamed(AppRoute.v2RegistrationConfirmation.name);
                },
              );
            },
          );
        },
      ),
      GoRoute(
        name: AppRoute.v2RegistrationManufacturer.name,
        path: AppRoute.v2RegistrationManufacturer.path,
        builder: (BuildContext context, GoRouterState state) {
          return registrationManufacturerBuilder?.call(context) ??
              V2RegistrationManufacturerScreen(
                onManufacturerSelected: (_) {
                  context.pushNamed(AppRoute.v2RegistrationConfirmation.name);
                },
                onUnknownSelected: () {
                  context.pushNamed(AppRoute.v2RegistrationConfirmation.name);
                },
              );
        },
      ),
      GoRoute(
        name: AppRoute.v2RegistrationConfirmation.name,
        path: AppRoute.v2RegistrationConfirmation.path,
        builder: (BuildContext context, GoRouterState state) {
          final override = registrationConfirmationBuilder;
          if (override != null) {
            return override(context);
          }

          return Consumer(
            builder: (context, ref, _) {
              return V2RegistrationConfirmationScreen(
                onSubmit: () async {
                  await V2RegistrationAuthGate.run(
                    context,
                    ref,
                    actionLabel: '自販機の登録',
                    action: () async {
                      final registration = ref.read(
                        machineRegistrationControllerProvider.notifier,
                      );
                      final submitted = await registration.submit();
                      if (!submitted || !context.mounted) {
                        return;
                      }

                      final machineId = ref
                          .read(machineRegistrationControllerProvider)
                          .createdMachineId;
                      if (machineId == null) {
                        return;
                      }

                      await _refreshRegistrationAffectedSearches(ref);
                      if (!context.mounted) {
                        return;
                      }

                      final router = GoRouter.of(context);

                      // The detail provider reads Firestore directly, so the
                      // created machine can be opened immediately after Callable
                      // completion. Reset only after machineId is captured.
                      registration.reset();

                      // Remove the registration stack before opening detail.
                      router.goNamed(AppRoute.v2Foundation.name);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        router.pushNamed(
                          AppRoute.v2MachineDetail.name,
                          pathParameters: <String, String>{
                            'machineId': machineId.value,
                          },
                        );
                      });
                    },
                  );
                },
              );
            },
          );
        },
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) {
      return RouteErrorScreen(location: state.uri.toString());
    },
  );
}

Future<void> _refreshRegistrationAffectedSearches(WidgetRef ref) async {
  final viewport = ref.read(vendingMachineMapControllerProvider).lastViewport;
  if (viewport == null) {
    return;
  }

  await ref
      .read(vendingMachineMapControllerProvider.notifier)
      .loadViewport(viewport, force: true);

  final selectedProduct = ref.read(productSearchSelectionControllerProvider);
  if (selectedProduct != null) {
    await ref
        .read(productMachineSearchControllerProvider.notifier)
        .search(productId: selectedProduct.id, viewport: viewport, force: true);
    return;
  }

  final selectedGenre = ref.read(genreSearchSelectionControllerProvider);
  if (selectedGenre != null) {
    await ref
        .read(genreMachineSearchControllerProvider.notifier)
        .search(genre: selectedGenre, viewport: viewport, force: true);
  }
}

class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.route_outlined, size: 44),
              const SizedBox(height: 12),
              const Text(
                '画面を表示できませんでした',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(location, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.goNamed(AppRoute.legacyRoot.name),
                child: const Text('現行画面へ戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
