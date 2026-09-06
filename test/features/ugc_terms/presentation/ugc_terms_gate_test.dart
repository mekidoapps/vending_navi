import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/ugc_terms/presentation/ugc_terms_gate.dart';

void main() {
  testWidgets('投稿ルールの確認はsmall viewportでも表示される', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UgcTermsSheet())));
    expect(find.text('投稿ルールの確認'), findsOneWidget);
    expect(find.text('同意して続ける'), findsOneWidget);
    expect(find.text('キャンセル'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同意済みならFirebase初期化なしで元の操作を続ける', (tester) async {
    final service = _FakeUgcTermsConsentService(accepted: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ugcTermsConsentServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: _GateTestScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('ensureTermsButton')));
    await tester.pumpAndSettle();

    expect(find.text('continued'), findsOneWidget);
    expect(find.text('投稿ルールの確認'), findsNothing);
    expect(service.acceptCallCount, 0);
  });

  testWidgets('未同意から同意すると元の操作を続ける', (tester) async {
    final service = _FakeUgcTermsConsentService(accepted: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ugcTermsConsentServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: _GateTestScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('ensureTermsButton')));
    await tester.pumpAndSettle();
    expect(find.text('投稿ルールの確認'), findsOneWidget);

    await tester.tap(find.text('同意して続ける'));
    await tester.pumpAndSettle();

    expect(find.text('continued'), findsOneWidget);
    expect(service.acceptCallCount, 1);
  });
}

class _GateTestScreen extends ConsumerStatefulWidget {
  const _GateTestScreen();

  @override
  ConsumerState<_GateTestScreen> createState() => _GateTestScreenState();
}

class _GateTestScreenState extends ConsumerState<_GateTestScreen> {
  var _continued = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        FilledButton(
          key: const Key('ensureTermsButton'),
          onPressed: () async {
            if (await UgcTermsGate.ensure(context, ref)) {
              setState(() => _continued = true);
            }
          },
          child: const Text('投稿する'),
        ),
        if (_continued) const Text('continued'),
      ],
    ),
  );
}

final class _FakeUgcTermsConsentService implements UgcTermsConsentService {
  _FakeUgcTermsConsentService({required this.accepted});

  final bool accepted;
  var acceptCallCount = 0;

  @override
  Future<void> acceptCurrentTerms() async {
    acceptCallCount += 1;
  }

  @override
  Future<bool> hasAcceptedCurrentTerms() async => accepted;
}
