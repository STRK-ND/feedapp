// GENERATED CODE - DO NOT MODIFY BY HAND
// dart run build_runner build

// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package

part of 'feed_state.dart';

class _$_Initial implements FeedInitial {
  const _$_Initial();

  @override
  String toString() {
    return 'FeedState.initial()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) || (other.runtimeType == _$_Initial);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _$_Loading implements FeedLoading {
  const _$_Loading();

  @override
  String toString() {
    return 'FeedState.loading()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) || (other.runtimeType == _$_Loading);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _$_Success implements FeedSuccess {
  const _$_Success(this.articles);

  @override
  final List<Article> articles;

  @override
  String toString() {
    return 'FeedState.success(articles: [...${articles.length} items])';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
      (other.runtimeType == _$_Success &&
        const DeepCollectionEquality().equals(articles, other.articles));
  }

  @override
  int get hashCode => Object.hash(runtimeType, articles);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _$_Error implements FeedError {
  const _$_Error(this.message);

  @override
  final String message;

  @override
  String toString() {
    return 'FeedState.error(message: $message)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
      (other.runtimeType == _$_Error &&
        (identical(message, other.message) || message == other.message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _$_LoadingMore implements FeedLoadingMore {
  const _$_LoadingMore(this.currentArticles);

  @override
  final List<Article> currentArticles;

  @override
  String toString() {
    return 'FeedState.loadingMore(currentArticles: [...${currentArticles.length} items])';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
      (other.runtimeType == _$_LoadingMore &&
        const DeepCollectionEquality().equals(currentArticles, other.currentArticles));
  }

  @override
  int get hashCode => Object.hash(runtimeType, currentArticles);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}