import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/outbox_mutation.dart';

/// Service for managing offline mutation queue (outbox pattern)
/// Queues mutations when offline and replays them when connectivity returns
class OutboxService {
  static const String _outboxKey = 'outbox_mutations';
  static const int _maxRetries = 3;
  static const int _maxAgeHours = 24;

  final FlutterSecureStorage _storage;

  OutboxService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Add a mutation to the outbox
  Future<void> enqueue(OutboxMutation mutation) async {
    final mutations = await _loadMutations();

    // Check if there's already a mutation for this article+type combination
    // If so, update it instead of adding duplicate
    final existingIndex = mutations.indexWhere(
      (m) => m.articleId == mutation.articleId && m.type == mutation.type,
    );

    if (existingIndex >= 0) {
      mutations[existingIndex] = mutation;
    } else {
      mutations.add(mutation);
    }

    await _saveMutations(mutations);
  }

  /// Get all pending mutations
  Future<List<OutboxMutation>> getPendingMutations() async {
    final mutations = await _loadMutations();

    // Filter out old mutations and those exceeding max retries
    final now = DateTime.now();
    final maxAge = Duration(hours: _maxAgeHours);

    return mutations.where((m) {
      if (m.retryCount >= _maxRetries) return false;
      if (now.difference(m.createdAt) > maxAge) return false;
      return true;
    }).toList();
  }

  /// Remove a mutation from the outbox after successful replay
  Future<void> dequeue(String mutationId) async {
    final mutations = await _loadMutations();
    mutations.removeWhere((m) => m.id == mutationId);
    await _saveMutations(mutations);
  }

  /// Increment retry count for a failed mutation
  Future<void> incrementRetry(String mutationId) async {
    final mutations = await _loadMutations();
    final index = mutations.indexWhere((m) => m.id == mutationId);

    if (index >= 0) {
      mutations[index] = mutations[index].copyWith(
        retryCount: mutations[index].retryCount + 1,
      );
      await _saveMutations(mutations);
    }
  }

  /// Clear all mutations (after successful replay or on reset)
  Future<void> clear() async {
    await _storage.delete(key: _outboxKey);
  }

  /// Get count of pending mutations (for UI badge)
  Future<int> getPendingCount() async {
    final pending = await getPendingMutations();
    return pending.length;
  }

  /// Remove expired mutations (cleanup)
  Future<int> removeExpired() async {
    final mutations = await _loadMutations();
    final now = DateTime.now();
    final maxAge = Duration(hours: _maxAgeHours);

    final originalCount = mutations.length;
    mutations.removeWhere((m) {
      if (m.retryCount >= _maxRetries) return true;
      if (now.difference(m.createdAt) > maxAge) return true;
      return false;
    });

    if (mutations.length != originalCount) {
      await _saveMutations(mutations);
    }

    return originalCount - mutations.length;
  }

  Future<List<OutboxMutation>> _loadMutations() async {
    try {
      final jsonString = await _storage.read(key: _outboxKey);
      if (jsonString == null) return [];

      final List<dynamic> decoded = json.decode(jsonString);
      return decoded
          .map((json) => OutboxMutation.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // On corruption, clear and start fresh
      await clear();
      return [];
    }
  }

  Future<void> _saveMutations(List<OutboxMutation> mutations) async {
    final jsonData = json.encode(mutations.map((m) => m.toJson()).toList());
    await _storage.write(key: _outboxKey, value: jsonData);
  }
}