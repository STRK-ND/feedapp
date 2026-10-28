/// Errors the Curated Feeds worker answers with, typed so the UI can map them
/// to real messages instead of matching on status-code text.
///
/// These live apart from `worker_feed_service.dart` so `error_handler.dart`
/// can recognise them without importing the service that throws them (which
/// would make the two libraries mutually dependent).
library;

/// The worker throttled the caller (429). Transient; the service retries it
/// with exponential backoff before surfacing it.
class RateLimitError implements Exception {
  final String message;
  final Duration? retryAfter;

  RateLimitError({this.message = 'Rate limit exceeded', this.retryAfter});

  @override
  String toString() => 'RateLimitError: $message';
}

/// The worker is mid-refresh and has no cached feed to serve. It answers 503
/// with `{"error":"busy","message":"..."}`; transient, so the service retries
/// it like a rate limit before giving up.
class WorkerBusyException implements Exception {
  final String message;

  WorkerBusyException({this.message = 'Feed is refreshing'});

  @override
  String toString() => 'WorkerBusyException: $message';
}
