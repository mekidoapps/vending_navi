import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/content_blocking/application/blocked_content_state.dart';
import 'package:vending_app/features/user_profile/application/providers/user_profile_providers.dart';
import 'package:vending_app/features/user_profile/domain/entities/user_profile.dart';
import 'package:vending_app/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:vending_app/features/user_profile/presentation/v2_my_page_screen.dart';

void main() {
  testWidgets('authenticated empty state shows safe blocked-content settings', (
    tester,
  ) async {
    await _pump(tester, gateway: _Gateway());

    expect(find.text('非表示設定'), findsOneWidget);
    expect(find.text('非表示にしたコンテンツはありません。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest shows the guest view without blocked-content settings', (
    tester,
  ) async {
    await _pump(tester, gateway: _Gateway(), guest: true);

    expect(find.byKey(const Key('v2MyPageGuestView')), findsOneWidget);
    expect(find.text('非表示設定'), findsNothing);
  });

  testWidgets('actor and every content kind use anonymous labels only', (
    tester,
  ) async {
    await _pump(tester, gateway: _Gateway(entries: _entries()));

    expect(find.text('投稿者由来コンテンツ'), findsOneWidget);
    expect(find.text('自販機'), findsOneWidget);
    expect(find.text('写真'), findsOneWidget);
    expect(find.text('商品'), findsOneWidget);
    expect(find.text('その他コンテンツ'), findsOneWidget);
    expect(find.text('actor_uid_should_never_render'), findsNothing);
    expect(find.text('raw_handle_should_never_render'), findsNothing);
    expect(find.text('private/path/should_never_render'), findsNothing);
    expect(find.text('private@example.invalid'), findsNothing);
  });

  testWidgets('unblock sends only the safe handle then reflects server refresh', (
    tester,
  ) async {
    final gateway = _Gateway(entries: _entries());
    await _pump(tester, gateway: gateway);

    await tester.tap(find.text('解除').at(2));
    await tester.pumpAndSettle();

    expect(gateway.changedHandles, <String>['raw_handle_should_never_render']);
    expect(gateway.readCount, greaterThanOrEqualTo(2));
    expect(find.text('写真'), findsNothing);
    expect(find.text('投稿者由来コンテンツ'), findsOneWidget);
    expect(find.text('自販機'), findsOneWidget);
    expect(find.text('商品'), findsOneWidget);
    expect(find.text('その他コンテンツ'), findsOneWidget);
  });

  testWidgets('unblock failure keeps every entry and shows a safe error', (
    tester,
  ) async {
    final gateway = _Gateway(entries: _entries(), failChange: true);
    await _pump(tester, gateway: gateway);

    await tester.tap(find.text('解除').at(1));
    await tester.pumpAndSettle();

    expect(find.text('非表示設定を解除できませんでした'), findsOneWidget);
    expect(find.text('投稿者由来コンテンツ'), findsOneWidget);
    expect(find.text('自販機'), findsOneWidget);
    expect(find.text('写真'), findsOneWidget);
    expect(find.text('商品'), findsOneWidget);
    expect(find.text('その他コンテンツ'), findsOneWidget);
    expect(find.text('raw_handle_should_never_render'), findsNothing);
  });

  testWidgets('multiple settings fit and remain actionable at 320x568', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, gateway: _Gateway(entries: _entries()));

    await tester.ensureVisible(find.text('解除').last);
    expect(find.text('解除').last, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text keeps blocked settings labels and actions usable', (
    tester,
  ) async {
    await _pump(
      tester,
      gateway: _Gateway(entries: _entries()),
      textScaler: const TextScaler.linear(1.6),
    );

    await tester.ensureVisible(find.text('解除').last);
    expect(find.text('その他コンテンツ'), findsOneWidget);
    expect(find.text('解除').last, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required _Gateway gateway,
  bool guest = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final session = guest ? const GuestAuthSession() : _authenticatedSession();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(_AuthRepository(session)),
        userProfileRepositoryProvider.overrideWithValue(_ProfileRepository()),
        blockedContentGatewayProvider.overrideWithValue(gateway),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: const MaterialApp(home: V2MyPageScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<BlockedContentEntry> _entries() => const <BlockedContentEntry>[
  BlockedContentEntry(
    handle: 'actor_uid_should_never_render',
    kind: 'actor',
    targetType: 'machine',
    machineId: 'machine_a',
  ),
  BlockedContentEntry(
    handle: 'machine_handle_should_never_render',
    kind: 'content',
    targetType: 'machine',
    machineId: 'machine_b',
  ),
  BlockedContentEntry(
    handle: 'raw_handle_should_never_render',
    kind: 'content',
    targetType: 'photo',
    machineId: 'machine_c',
    photoId: 'private/path/should_never_render',
  ),
  BlockedContentEntry(
    handle: 'product_handle_should_never_render',
    kind: 'content',
    targetType: 'product',
    machineId: 'machine_d',
    productId: 'private@example.invalid',
  ),
  BlockedContentEntry(
    handle: 'other_handle_should_never_render',
    kind: 'content',
    targetType: 'text',
    machineId: 'machine_e',
  ),
];

AuthSession _authenticatedSession() => AuthenticatedAuthSession(
  AuthUser(
    uid: 'screen_user',
    email: null,
    displayName: '匿名ユーザー',
    providerIds: const <String>['password'],
    emailVerified: true,
  ),
);

final class _Gateway implements BlockedContentGateway {
  _Gateway({List<BlockedContentEntry>? entries, this.failChange = false})
    : _entries = List<BlockedContentEntry>.from(entries ?? const <BlockedContentEntry>[]);

  List<BlockedContentEntry> _entries;
  final bool failChange;
  var readCount = 0;
  final List<String> changedHandles = <String>[];

  @override
  Future<void> change({
    required String operation,
    required Map<String, Object?> data,
  }) async {
    if (failChange) throw StateError('private failure');
    final handle = data['handle']! as String;
    changedHandles.add(handle);
    _entries = _entries.where((entry) => entry.handle != handle).toList();
  }

  @override
  Future<Object?> getBlockedContentIds() async {
    readCount += 1;
    return <String, Object?>{
      'machineIds': _entries
          .where((entry) => entry.targetType == 'machine')
          .map((entry) => entry.machineId)
          .whereType<String>()
          .toList(),
      'photoIds': _entries.map((entry) => entry.photoId).whereType<String>().toList(),
      'productIds': _entries
          .map((entry) => entry.productId)
          .whereType<String>()
          .toList(),
      'blocks': _entries
          .map(
            (entry) => <String, Object?>{
              'handle': entry.handle,
              'kind': entry.kind,
              'targetType': entry.targetType,
              'machineId': entry.machineId,
              'photoId': entry.photoId,
              'productId': entry.productId,
            },
          )
          .toList(),
    };
  }

  @override
  Future<Object?> resolveContentBlockMode(Map<String, Object?> data) =>
      throw UnimplementedError();
}

final class _AuthRepository implements AuthRepository {
  _AuthRepository(this._session);
  final AuthSession _session;
  @override
  AuthSession get currentSession => _session;
  @override
  Stream<AuthSession> watchSession() => Stream<AuthSession>.value(_session);
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

final class _ProfileRepository implements UserProfileRepository {
  @override
  Future<AppResult<UserProfile>> getOrCreateProfile({required String uid}) async =>
      AppResult<UserProfile>.success(UserProfile(uid: uid));
  @override
  Future<AppResult<UserProfile>> saveDisplayName({required String uid, required String? displayName}) => throw UnimplementedError();
}
