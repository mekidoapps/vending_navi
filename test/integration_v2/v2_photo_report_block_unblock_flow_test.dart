import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vending_app/app/router/app_route.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/content_blocking/application/blocked_content_state.dart';
import 'package:vending_app/features/machine_update/application/machine_report_controller.dart';
import 'package:vending_app/features/machine_update/application/providers/machine_report_providers.dart';
import 'package:vending_app/features/machine_update/domain/models/machine_report_draft.dart';
import 'package:vending_app/features/machine_update/domain/models/machine_report_result.dart';
import 'package:vending_app/features/machine_update/domain/repositories/machine_report_repository.dart';
import 'package:vending_app/features/machine_update/presentation/v2_machine_report_confirmation_screen.dart';
import 'package:vending_app/features/machine_update/presentation/v2_machine_report_screen.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/user_profile/application/providers/user_profile_providers.dart';
import 'package:vending_app/features/user_profile/domain/entities/user_profile.dart';
import 'package:vending_app/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:vending_app/features/user_profile/presentation/v2_my_page_screen.dart';
import 'package:vending_app/features/vending_machine/application/models/vending_machine_detail_data.dart';
import 'package:vending_app/features/vending_machine/application/providers/vending_machine_detail_providers.dart';
import 'package:vending_app/features/vending_machine/domain/entities/public_machine_photo.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';
import 'package:vending_app/features/vending_machine/presentation/v2_vending_machine_detail_screen.dart';

const machineId = 'machine-a', photoId = 'photo-a', handle = 'safe_handle_never_render';
final machine = VendingMachine(id: VendingMachineId.parse(machineId), schemaVersion: 2, name: 'テスト自販機', manufacturerStatus: ManufacturerStatus.unknown, location: GeoCoordinate(latitude: 35.68, longitude: 139.76), geohash: 'xn76', installationType: InstallationType.outdoor, status: VendingMachineStatus.active, dataLevel: VendingMachineDataLevel.productsConfirmed);
const photo = PublicMachinePhoto(photoId: photoId, status: 'active');

void main() {
  testWidgets('formal photo report to block, MyPage unblock, then detail restore', (tester) async {
    final blocks = _Blocks(); final reports = _Reports();
    final c = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_Auth()), userProfileRepositoryProvider.overrideWithValue(_Profiles()),
      blockedContentGatewayProvider.overrideWithValue(blocks), machineReportRepositoryProvider.overrideWithValue(reports),
      vendingMachineDetailProvider(machine.id).overrideWithValue(AsyncData(AppResult<VendingMachineDetailData>.success(_detail()))),
      formalMachinePhotoUrlProvider.overrideWith((ref, target) async => ''),
    ]); addTearDown(c.dispose);
    final r = GoRouter(initialLocation: '/v2/machines/$machineId', routes: [
      GoRoute(name: AppRoute.v2MachineDetail.name, path: AppRoute.v2MachineDetail.path, builder: (_,__) => V2VendingMachineDetailScreen(machineId: machine.id)),
      GoRoute(name: AppRoute.v2MachineReport.name, path: AppRoute.v2MachineReport.path, builder: (x,s) => V2MachineReportScreen(machineId: machine.id, photoId: s.uri.queryParameters['photoId'], onReviewPressed: () => x.pushNamed(AppRoute.v2MachineReportConfirmation.name, pathParameters: {'machineId': machineId}))),
      GoRoute(name: AppRoute.v2MachineReportConfirmation.name, path: AppRoute.v2MachineReportConfirmation.path, builder: (x,_) => V2MachineReportConfirmationScreen(machineId: machine.id, onCompleted: () { c.read(machineReportControllerProvider.notifier).reset(); x.goNamed(AppRoute.v2MachineDetail.name, pathParameters: {'machineId': machineId}); })),
      GoRoute(name: AppRoute.v2MyPage.name, path: AppRoute.v2MyPage.path, builder: (_,__) => const V2MyPageScreen()),
    ]); addTearDown(r.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp.router(routerConfig: r))); await tester.pumpAndSettle();
    expect(photo.displayReferenceFor(machineId), 'vending_machines/machine-a/photo-a/original.jpg');
    expect(find.byKey(const Key('formalPhoto_photo-a')), findsOneWidget);

    await tester.tap(find.byKey(const Key('photoActions_photo-a'))); await tester.pumpAndSettle();
    await tester.tap(find.text('この写真を報告')); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('machineReportCategory_inappropriatePhoto'))); await tester.tap(find.byKey(const Key('machineReportReviewButton'))); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submitMachineReportButton'))); await tester.pumpAndSettle();
    expect(reports.draft?.targetType, 'photo'); expect(reports.draft?.machineId.value, machineId); expect(reports.draft?.photoId, photoId);
    expect(find.text('この写真も非表示にしますか？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reportBlockConfirmButton'))); await tester.pumpAndSettle();
    expect(blocks.blocked, isTrue); expect(find.byKey(const Key('formalPhoto_photo-a')), findsNothing); expect(find.text('テスト自販機'), findsOneWidget); expect(find.text('商品A'), findsOneWidget);

    r.goNamed(AppRoute.v2MyPage.name); await tester.pumpAndSettle();
    expect(find.text('写真'), findsOneWidget); expect(find.text(handle), findsNothing); expect(find.text('actor_uid_never_render'), findsNothing); expect(find.text('private/path/never_render'), findsNothing);
    await tester.tap(find.text('解除')); await tester.pumpAndSettle();
    expect(blocks.unblocked, <String>[handle]); expect(find.text('非表示にしたコンテンツはありません。'), findsOneWidget);
    r.goNamed(AppRoute.v2MachineDetail.name, pathParameters: {'machineId': machineId}); await tester.pumpAndSettle();
    expect(find.byKey(const Key('formalPhoto_photo-a')), findsOneWidget); expect(tester.takeException(), isNull);
  });
}

VendingMachineDetailData _detail() => VendingMachineDetailData(machine: machine, manufacturerName: 'メーカー', photos: const [photo], products: [VendingMachineProductDetailItem(productId: ProductId.parse('product_a'), productName: '商品A', evidenceType: ProductEvidenceType.manualConfirmed, availability: ProductAvailability.available)]);

final class _Blocks implements BlockedContentGateway {
  bool blocked = false; final List<String> unblocked = [];
  @override Future<void> change({required String operation, required Map<String,Object?> data}) async { if(operation == 'blockContentSource') { expect(data, {'targetType':'photo','machineId':machineId,'photoId':photoId,'productId':null}); blocked=true; } else { unblocked.add(data['handle']! as String); blocked=false; } }
  @override Future<Object?> getBlockedContentIds() async => {'machineIds': <String>[], 'photoIds': blocked ? <String>[photoId] : <String>[], 'productIds': <String>[], 'blocks': blocked ? <Map<String,Object?>>[{'handle':handle,'kind':'content','targetType':'photo','machineId':machineId,'photoId':photoId}] : <Map<String,Object?>>[]};
  @override Future<Object?> resolveContentBlockMode(Map<String,Object?> data) async => {'blockMode':'content'};
}
final class _Reports implements MachineReportRepository { MachineReportDraft? draft; @override Future<AppResult<MachineReportResult>> submitReport({required String requestId,required MachineReportDraft draft}) async { this.draft=draft; return AppResult.success(MachineReportResult(machineId: draft.machineId,reportId:'report-a')); } }
final class _Auth implements AuthRepository { final s=AuthenticatedAuthSession(AuthUser(uid:'actor_uid_never_render',email:null,displayName:'display_name_never_render',providerIds:['password'],emailVerified:true)); @override AuthSession get currentSession=>s; @override Stream<AuthSession> watchSession()=>Stream.value(s); @override Future<AppResult<AuthSession>> signInWithEmail({required String email,required String password})=>throw UnimplementedError(); @override Future<AppResult<AuthSession>> registerWithEmail({required String email,required String password})=>throw UnimplementedError(); @override Future<AppResult<bool>> reauthenticateWithPassword({required String password})=>throw UnimplementedError(); @override Future<AppResult<AuthSession>> signOut()=>throw UnimplementedError(); @override Future<AppResult<bool>> sendPasswordResetEmail({required String email})=>throw UnimplementedError(); }
final class _Profiles implements UserProfileRepository { @override Future<AppResult<UserProfile>> getOrCreateProfile({required String uid}) async=>AppResult.success(UserProfile(uid:uid)); @override Future<AppResult<UserProfile>> saveDisplayName({required String uid,required String? displayName})=>throw UnimplementedError(); }
