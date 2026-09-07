import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/providers/auth_providers.dart';
import '../../auth/domain/entities/auth_session.dart';

abstract interface class BlockedContentGateway {
  Future<Object?> getBlockedContentIds();
  Future<Object?> resolveContentBlockMode(Map<String, Object?> data);
  Future<void> change({
    required String operation,
    required Map<String, Object?> data,
  });
}

final class FirebaseBlockedContentGateway implements BlockedContentGateway {
  FirebaseBlockedContentGateway(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<Object?> getBlockedContentIds() async =>
      (await _functions.httpsCallable('getBlockedContentIds').call<Object?>())
          .data;

  @override
  Future<Object?> resolveContentBlockMode(Map<String, Object?> data) async =>
      (await _functions
              .httpsCallable('resolveContentBlockMode')
              .call<Object?>(data))
          .data;

  @override
  Future<void> change({
    required String operation,
    required Map<String, Object?> data,
  }) async {
    await _functions.httpsCallable(operation).call<Object?>(data);
  }
}

final blockedContentGatewayProvider = Provider<BlockedContentGateway>(
  (ref) => FirebaseBlockedContentGateway(ref.watch(cloudFunctionsProvider)),
  name: 'blockedContentGatewayProvider',
);

enum ContentBlockMode { actor, content }

final class ContentBlockTarget {
  const ContentBlockTarget({
    required this.targetType,
    required this.machineId,
    this.photoId,
    this.productId,
  });

  final String targetType;
  final String machineId;
  final String? photoId;
  final String? productId;

  @override
  bool operator ==(Object other) =>
      other is ContentBlockTarget &&
      other.targetType == targetType &&
      other.machineId == machineId &&
      other.photoId == photoId &&
      other.productId == productId;

  @override
  int get hashCode => Object.hash(targetType, machineId, photoId, productId);

  Map<String, Object?> toMap() => <String, Object?>{
    'targetType': targetType,
    'machineId': machineId,
    'photoId': photoId,
    'productId': productId,
  };
}

final contentBlockModeProvider =
    FutureProvider.family<ContentBlockMode, ContentBlockTarget>((
      ref,
      target,
    ) async {
      final data = await ref
          .watch(blockedContentGatewayProvider)
          .resolveContentBlockMode(target.toMap());
      if (data is Map && data['blockMode'] == 'actor') {
        return ContentBlockMode.actor;
      }
      return ContentBlockMode.content;
    }, name: 'contentBlockModeProvider');

final blockedContentProvider =
    NotifierProvider<BlockedContentController, BlockedContentState>(
      BlockedContentController.new,
    );

final class BlockedContentState {
  const BlockedContentState({
    this.machineIds = const <String>{},
    this.photoIds = const <String>{},
    this.productIds = const <String>{},
    this.blocks = const <BlockedContentEntry>[],
  });

  final Set<String> machineIds;
  final Set<String> photoIds;
  final Set<String> productIds;
  final List<BlockedContentEntry> blocks;
}

final class BlockedContentEntry {
  const BlockedContentEntry({
    required this.handle,
    required this.kind,
    required this.targetType,
    this.machineId,
    this.photoId,
    this.productId,
  });
  final String handle;
  final String kind;
  final String targetType;
  final String? machineId;
  final String? photoId;
  final String? productId;
}

final class BlockedContentController extends Notifier<BlockedContentState> {
  var _generation = 0;
  String? _uid;

  @override
  BlockedContentState build() {
    ref.listen<AsyncValue<AuthSession>>(authSessionChangesProvider, (_, next) {
      final session = next.asData?.value;
      final uid = session?.userOrNull?.uid;
      if (uid == _uid) return;
      _uid = uid;
      final generation = ++_generation;
      state = const BlockedContentState();
      if (uid != null) refresh(expectedGeneration: generation);
    }, fireImmediately: true);
    return const BlockedContentState();
  }

  Future<void> refresh({int? expectedGeneration}) async {
    final generation = expectedGeneration ?? _generation;
    try {
      final data = await ref
          .read(blockedContentGatewayProvider)
          .getBlockedContentIds();
      if (data is! Map) return;
      Set<String> ids(String key) => ((data[key] as List?) ?? const <Object>[])
          .whereType<String>()
          .toSet();
      if (generation != _generation) return;
      state = BlockedContentState(
        machineIds: ids('machineIds'),
        photoIds: ids('photoIds'),
        productIds: ids('productIds'),
        blocks: ((data['blocks'] as List?) ?? const <Object>[])
            .whereType<Map>()
            .map(
              (item) => BlockedContentEntry(
                handle: item['handle'] as String? ?? '',
                kind: item['kind'] as String? ?? 'content',
                targetType: item['targetType'] as String? ?? 'machine',
                machineId: item['machineId'] as String?,
                photoId: item['photoId'] as String?,
                productId: item['productId'] as String?,
              ),
            )
            .where((item) => item.handle.isNotEmpty)
            .toList(),
      );
    } catch (_) {
      if (generation != _generation) return;
      state = const BlockedContentState();
    }
  }

  Future<bool> block({
    required String targetType,
    required String machineId,
    String? photoId,
    String? productId,
  }) =>
      _change('blockContentSource', targetType, machineId, photoId, productId);

  Future<bool> unblock({
    required String targetType,
    required String machineId,
    String? photoId,
    String? productId,
  }) => _change(
    'unblockContentSource',
    targetType,
    machineId,
    photoId,
    productId,
  );

  Future<bool> unblockHandle(String handle) async {
    try {
      await ref
          .read(blockedContentGatewayProvider)
          .change(
            operation: 'unblockContentSource',
            data: <String, Object?>{'handle': handle},
          );
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _change(
    String name,
    String targetType,
    String machineId,
    String? photoId,
    String? productId,
  ) async {
    try {
      await ref
          .read(blockedContentGatewayProvider)
          .change(
            operation: name,
            data: <String, Object?>{
              'targetType': targetType,
              'machineId': machineId,
              'photoId': photoId,
              'productId': productId,
            },
          );
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  void clear() {
    _uid = null;
    _generation += 1;
    state = const BlockedContentState();
  }
}
