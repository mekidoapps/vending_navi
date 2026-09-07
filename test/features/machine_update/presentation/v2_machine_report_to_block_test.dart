import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/content_blocking/application/blocked_content_state.dart';
import 'package:vending_app/features/machine_update/application/machine_report_controller.dart';
import 'package:vending_app/features/machine_update/application/providers/machine_report_providers.dart';
import 'package:vending_app/features/machine_update/domain/models/machine_report_category.dart';
import 'package:vending_app/features/machine_update/domain/models/machine_report_draft.dart';
import 'package:vending_app/features/machine_update/domain/models/machine_report_result.dart';
import 'package:vending_app/features/machine_update/domain/repositories/machine_report_repository.dart';
import 'package:vending_app/features/machine_update/presentation/v2_machine_report_confirmation_screen.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  testWidgets('machine report keeps success and blocks the same target in actor mode', (
    tester,
  ) async {
    final gateway = _Gateway(mode: ContentBlockMode.actor);
    final harness = await _pump(
      tester,
      gateway: gateway,
      draft: _draft(),
    );

    await _submit(tester);
    expect(find.text('この投稿者のコンテンツも非表示にしますか？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reportBlockConfirmButton')));
    await tester.pumpAndSettle();

    expect(gateway.changes, <_Target>[_Target('machine', _machineId, null, null)]);
    expect(harness.completed, 1);
    expect(_result(harness.container), isNotNull);
    expect(harness.container.read(blockedContentProvider).machineIds, <String>{_machineId});
  });

  testWidgets('machine content fallback succeeds without actor attribution', (
    tester,
  ) async {
    final gateway = _Gateway(mode: ContentBlockMode.content);
    final harness = await _pump(tester, gateway: gateway, draft: _draft());

    await _submit(tester);
    expect(find.text('この自販機も非表示にしますか？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reportBlockConfirmButton')));
    await tester.pumpAndSettle();

    expect(gateway.changes, <_Target>[_Target('machine', _machineId, null, null)]);
    expect(harness.completed, 1);
    expect(_result(harness.container), isNotNull);
  });

  testWidgets('machine cancel does not call block and keeps report success unchanged', (
    tester,
  ) async {
    final gateway = _Gateway(mode: ContentBlockMode.actor);
    final harness = await _pump(tester, gateway: gateway, draft: _draft());

    await _submit(tester);
    await tester.tap(find.byKey(const Key('reportBlockCancelButton')));
    await tester.pumpAndSettle();

    expect(gateway.changes, isEmpty);
    expect(harness.completed, 1);
    expect(_result(harness.container), isNotNull);
  });

  testWidgets('machine block failure does not turn report success into an error', (
    tester,
  ) async {
    final gateway = _Gateway(mode: ContentBlockMode.actor, failChange: true);
    final harness = await _pump(tester, gateway: gateway, draft: _draft());

    await _submit(tester);
    await tester.tap(find.byKey(const Key('reportBlockConfirmButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('報告を受け付けました。非表示設定を変更できませんでした。'),
      findsOneWidget,
    );
    expect(harness.completed, 1);
    expect(_result(harness.container), isNotNull);
    expect(harness.container.read(machineReportControllerProvider).failure, isNull);
  });

  testWidgets('photo report preserves its exact target for actor and content modes', (
    tester,
  ) async {
    const photoId = 'p_0123456789abcdef0123456789abcd';
    for (final mode in ContentBlockMode.values) {
      final gateway = _Gateway(mode: mode);
      final harness = await _pump(
        tester,
        gateway: gateway,
        draft: _draft(targetType: 'photo', photoId: photoId),
      );

      await _submit(tester);
      expect(
        find.text(
          mode == ContentBlockMode.actor
              ? 'この投稿者のコンテンツも非表示にしますか？'
              : 'この写真も非表示にしますか？',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('reportBlockConfirmButton')));
      await tester.pumpAndSettle();

      expect(gateway.changes, <_Target>[_Target('photo', _machineId, photoId, null)]);
      expect(harness.completed, 1);
      expect(_result(harness.container), isNotNull);
      harness.dispose();
    }
  });

  testWidgets('photo block failure retains the successful report', (tester) async {
    const photoId = 'p_abcdef0123456789abcdef0123456789';
    final gateway = _Gateway(mode: ContentBlockMode.content, failChange: true);
    final harness = await _pump(
      tester,
      gateway: gateway,
      draft: _draft(targetType: 'photo', photoId: photoId),
    );

    await _submit(tester);
    await tester.tap(find.byKey(const Key('reportBlockConfirmButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('報告を受け付けました。非表示設定を変更できませんでした。'),
      findsOneWidget,
    );
    expect(_result(harness.container), isNotNull);
  });

  testWidgets('product report preserves its exact target for actor and content modes', (
    tester,
  ) async {
    const productId = 'product_exact';
    for (final mode in ContentBlockMode.values) {
      final gateway = _Gateway(mode: mode);
      final harness = await _pump(
        tester,
        gateway: gateway,
        draft: _draft(targetType: 'product', productId: productId),
      );

      await _submit(tester);
      expect(
        find.text(
          mode == ContentBlockMode.actor
              ? 'この投稿者のコンテンツも非表示にしますか？'
              : 'この商品も非表示にしますか？',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('reportBlockConfirmButton')));
      await tester.pumpAndSettle();

      expect(gateway.changes, <_Target>[_Target('product', _machineId, null, productId)]);
      expect(harness.completed, 1);
      expect(_result(harness.container), isNotNull);
      harness.dispose();
    }
  });

  testWidgets('product block failure and mode lookup failure keep report success private', (
    tester,
  ) async {
    final failureGateway = _Gateway(mode: ContentBlockMode.content, failChange: true);
    final failureHarness = await _pump(
      tester,
      gateway: failureGateway,
      draft: _draft(targetType: 'product', productId: 'product_failure'),
    );
    await _submit(tester);
    await tester.tap(find.byKey(const Key('reportBlockConfirmButton')));
    await tester.pumpAndSettle();
    expect(
      find.text('報告を受け付けました。非表示設定を変更できませんでした。'),
      findsOneWidget,
    );
    expect(_result(failureHarness.container), isNotNull);
    failureHarness.dispose();

    final modeFailureGateway = _Gateway(
      mode: ContentBlockMode.actor,
      failModeResolution: true,
    );
    final modeFailureHarness = await _pump(
      tester,
      gateway: modeFailureGateway,
      draft: _draft(targetType: 'product', productId: 'product_mode_failure'),
    );
    await _submit(tester);
    expect(find.byKey(const Key('reportBlockConfirmButton')), findsNothing);
    expect(modeFailureGateway.changes, isEmpty);
    expect(_result(modeFailureHarness.container), isNotNull);
    expect(find.textContaining('uid'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
  });
}

const _machineId = 'machine_report_to_block';

Future<_Harness> _pump(
  WidgetTester tester, {
  required _Gateway gateway,
  required MachineReportDraft draft,
}) async {
  final container = ProviderContainer(
    overrides: <Override>[
      authRepositoryProvider.overrideWithValue(_GuestAuthRepository()),
      machineReportRepositoryProvider.overrideWithValue(_SuccessRepository()),
      blockedContentGatewayProvider.overrideWithValue(gateway),
    ],
  );
  final harness = _Harness(container);
  addTearDown(harness.dispose);
  container.read(machineReportControllerProvider.notifier).begin(draft);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: V2MachineReportConfirmationScreen(
          machineId: draft.machineId,
          onCompleted: () => harness.completed += 1,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('submitMachineReportButton')));
  await tester.pumpAndSettle();
}

MachineReportResult? _result(ProviderContainer container) =>
    container.read(machineReportControllerProvider).result;

MachineReportDraft _draft({
  String? targetType,
  String? photoId,
  String? productId,
}) => MachineReportDraft(
  machineId: VendingMachineId.parse(_machineId),
  category: MachineReportCategory.inappropriatePhoto,
  targetType: targetType,
  photoId: photoId,
  productId: productId,
);

final class _Harness {
  _Harness(this.container);
  final ProviderContainer container;
  var completed = 0;
  void dispose() => container.dispose();
}

final class _SuccessRepository implements MachineReportRepository {
  @override
  Future<AppResult<MachineReportResult>> submitReport({
    required String requestId,
    required MachineReportDraft draft,
  }) async => AppResult<MachineReportResult>.success(
    MachineReportResult(machineId: draft.machineId, reportId: 'r_0123456789abcdef0123456789abcd'),
  );
}

final class _Gateway implements BlockedContentGateway {
  _Gateway({
    required this.mode,
    this.failChange = false,
    this.failModeResolution = false,
  });
  final ContentBlockMode mode;
  final bool failChange;
  final bool failModeResolution;
  final List<_Target> changes = <_Target>[];

  @override
  Future<void> change({
    required String operation,
    required Map<String, Object?> data,
  }) async {
    if (failChange) throw StateError('private failure');
    changes.add(_Target(
      data['targetType']! as String,
      data['machineId']! as String,
      data['photoId'] as String?,
      data['productId'] as String?,
    ));
  }

  @override
  Future<Object?> getBlockedContentIds() async => <String, Object?>{
    'machineIds': changes.where((item) => item.type == 'machine').map((item) => item.machineId).toList(),
    'photoIds': changes.where((item) => item.photoId != null).map((item) => item.photoId).toList(),
    'productIds': changes.where((item) => item.productId != null).map((item) => item.productId).toList(),
  };

  @override
  Future<Object?> resolveContentBlockMode(Map<String, Object?> data) async {
    if (failModeResolution) throw StateError('private mode failure');
    return <String, Object?>{'blockMode': mode.name};
  }
}

final class _Target {
  const _Target(this.type, this.machineId, this.photoId, this.productId);
  final String type;
  final String machineId;
  final String? photoId;
  final String? productId;
  @override
  bool operator ==(Object other) => other is _Target && other.type == type && other.machineId == machineId && other.photoId == photoId && other.productId == productId;
  @override
  int get hashCode => Object.hash(type, machineId, photoId, productId);
}

final class _GuestAuthRepository implements AuthRepository {
  @override
  AuthSession get currentSession => const GuestAuthSession();
  @override
  Stream<AuthSession> watchSession() => Stream<AuthSession>.value(const GuestAuthSession());
  @override
  Future<AppResult<AuthSession>> registerWithEmail({required String email, required String password}) => throw UnimplementedError();
  @override
  Future<AppResult<bool>> reauthenticateWithPassword({required String password}) => throw UnimplementedError();
  @override
  Future<AppResult<bool>> sendPasswordResetEmail({required String email}) => throw UnimplementedError();
  @override
  Future<AppResult<AuthSession>> signInWithEmail({required String email, required String password}) => throw UnimplementedError();
  @override
  Future<AppResult<AuthSession>> signOut() => throw UnimplementedError();
}
