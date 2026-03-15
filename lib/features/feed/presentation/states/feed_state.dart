// lib/features/feed/presentation/states/feed_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:curatedfeeds/models/article.dart';

part 'feed_state.freezed.dart';

@freezed
class FeedState with _$FeedState {
  const factory FeedState.initial() = FeedInitial;
  const factory FeedState.loading() = FeedLoading;
  const factory FeedState.success(List<Article> articles) = FeedSuccess;
  const factory FeedState.error(String message) = FeedError;
  const factory FeedState.loadingMore(List<Article> articles) = FeedLoadingMore;
}
