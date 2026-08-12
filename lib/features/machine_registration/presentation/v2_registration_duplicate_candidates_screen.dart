import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../vending_machine/domain/entities/vending_machine.dart';
import '../application/registration_duplicate_candidates_controller.dart';
import '../application/registration_duplicate_candidates_state.dart';
import '../domain/models/registration_duplicate_candidate.dart';

typedef RegistrationCandidateCallback = void Function(VendingMachine machine);

class V2RegistrationDuplicateCandidatesScreen extends ConsumerStatefulWidget {
  const V2RegistrationDuplicateCandidatesScreen({
    super.key,
    required this.onContinue,
    this.onViewCandidate,
    this.onUpdateCandidate,
  });

  final VoidCallback onContinue;
  final RegistrationCandidateCallback? onViewCandidate;
  final RegistrationCandidateCallback? onUpdateCandidate;

  @override
  ConsumerState<V2RegistrationDuplicateCandidatesScreen> createState() =>
      _V2RegistrationDuplicateCandidatesScreenState();
}

class _V2RegistrationDuplicateCandidatesScreenState
    extends ConsumerState<V2RegistrationDuplicateCandidatesScreen> {
  bool _continuedAutomatically = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(registrationDuplicateCandidatesControllerProvider.notifier)
            .load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationDuplicateCandidatesControllerProvider);

    if (state.isEmpty && !_continuedAutomatically) {
      _continuedAutomatically = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _continueWithNewMachine();
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('近くの自販機を確認')),
      body: SafeArea(
        child: _Body(
          state: state,
          onRetry: () {
            _continuedAutomatically = false;
            ref
                .read(
                  registrationDuplicateCandidatesControllerProvider.notifier,
                )
                .retry();
          },
          onViewCandidate: widget.onViewCandidate,
          onUpdateCandidate: widget.onUpdateCandidate,
          onContinue: _continueWithNewMachine,
        ),
      ),
    );
  }

  void _continueWithNewMachine() {
    ref
        .read(registrationDuplicateCandidatesControllerProvider.notifier)
        .continueWithNewMachine();
    widget.onContinue();
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.onRetry,
    required this.onViewCandidate,
    required this.onUpdateCandidate,
    required this.onContinue,
  });

  final RegistrationDuplicateCandidatesState state;
  final VoidCallback onRetry;
  final RegistrationCandidateCallback? onViewCandidate;
  final RegistrationCandidateCallback? onUpdateCandidate;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading || !state.hasLoaded) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('registrationDuplicateLoading'),
        ),
      );
    }

    final failure = state.failure;
    if (failure != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(V2Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: V2Spacing.sm),
              Text(
                failure.userTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: V2Spacing.xs),
              Text(failure.userMessage, textAlign: TextAlign.center),
              const SizedBox(height: V2Spacing.md),
              FilledButton.icon(
                key: const Key('registrationDuplicateRetryButton'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('もう一度確認'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.candidates.isEmpty) {
      return const Center(
        child: Text(
          '次の画面へ進みます…',
          key: Key('registrationDuplicateAutoContinue'),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            V2Spacing.lg,
            V2Spacing.md,
            V2Spacing.lg,
            V2Spacing.sm,
          ),
          child: Column(
            children: <Widget>[
              Text(
                '近くに登録済みの自販機があります',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: V2Spacing.xs),
              const Text(
                '同じ自販機でないか確認してください。近くに複数台ある場合は、そのまま登録を続けられます。',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            key: const Key('registrationDuplicateCandidateList'),
            padding: const EdgeInsets.all(V2Spacing.md),
            itemCount: state.candidates.length,
            separatorBuilder: (_, _) => const SizedBox(height: V2Spacing.sm),
            itemBuilder: (context, index) {
              final candidate = state.candidates[index];
              return _CandidateCard(
                candidate: candidate,
                onView: onViewCandidate == null
                    ? null
                    : () => onViewCandidate!(candidate.machine),
                onUpdate: onUpdateCandidate == null
                    ? null
                    : () => onUpdateCandidate!(candidate.machine),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            V2Spacing.lg,
            V2Spacing.sm,
            V2Spacing.lg,
            V2Spacing.lg,
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('registrationDuplicateContinueButton'),
              onPressed: onContinue,
              child: const Text('別の自販機として登録を続ける'),
            ),
          ),
        ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.onView,
    required this.onUpdate,
  });

  final RegistrationDuplicateCandidate candidate;
  final VoidCallback? onView;
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final machine = candidate.machine;
    final manufacturer =
        machine.manufacturerId?.value.replaceAll('_', ' ') ?? 'メーカー不明';

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: V2Radius.card),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const CircleAvatar(child: Icon(Icons.local_drink_outlined)),
                const SizedBox(width: V2Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        machine.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: V2Spacing.xxs),
                      Text(manufacturer),
                    ],
                  ),
                ),
                Text(
                  '${candidate.distanceMeters.round()}m',
                  key: Key('registrationDuplicateDistance_${machine.id.value}'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: V2Spacing.md),
            Wrap(
              spacing: V2Spacing.sm,
              runSpacing: V2Spacing.xs,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('既存情報を見る'),
                ),
                OutlinedButton.icon(
                  onPressed: onUpdate,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('この自販機を更新'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
