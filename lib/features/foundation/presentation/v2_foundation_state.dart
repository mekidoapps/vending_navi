import 'package:freezed_annotation/freezed_annotation.dart';

part 'v2_foundation_state.freezed.dart';
part 'v2_foundation_state.g.dart';

/// Phase 1でFreezedとjson_serializableのコード生成を確認するための
/// 最小状態モデル。
///
/// 実機能の状態をこのクラスへ追加せず、後続Featureごとに専用Stateを作る。
@freezed
abstract class V2FoundationState with _$V2FoundationState {
  const factory V2FoundationState({
    @Default(false) bool isReady,
    String? message,
  }) = _V2FoundationState;

  factory V2FoundationState.fromJson(Map<String, dynamic> json) =>
      _$V2FoundationStateFromJson(json);
}
