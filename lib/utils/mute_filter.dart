/// Muted-keyword filtering (shared contract).
///
/// A muted term hides any feed article whose title or description contains
/// it (case-insensitive substring). One pure module so the client filter,
/// the settings normalizer and the tests all agree on the same rules — the
/// worker mirrors the same matching in `applyFilters` and the push fan-out
/// (`workers/feed-worker.js`), so keep the two implementations in lockstep.
library;

import '../models/article.dart';

/// Upper bounds for the muted list. Mirrored by the worker's `mute=`
/// param clamp and by the push preferences payload.
const int maxMutedTerms = 50;
const int maxMutedTermLength = 64;

/// Normalize a raw muted-terms list: trim, lowercase, drop empties,
/// dedupe case-insensitively, clip each term to [maxMutedTermLength] and
/// cap the list at [maxMutedTerms] (first wins). Commas inside an entry
/// split into separate terms — the worker receives the list as a
/// comma-joined `mute=` param, so a comma can never live inside a term.
/// Pure.
List<String> normalizeMutedTerms(
  Iterable<String> raw, {
  int maxTerms = maxMutedTerms,
  int maxTermLength = maxMutedTermLength,
}) {
  final seen = <String>{};
  final out = <String>[];
  for (final entry in raw) {
    for (final piece in entry.split(',')) {
      final term = piece.trim().toLowerCase();
      if (term.isEmpty) continue;
      final clipped = term.length > maxTermLength
          ? term.substring(0, maxTermLength)
          : term;
      if (!seen.add(clipped)) continue;
      out.add(clipped);
      if (out.length >= maxTerms) return out;
    }
  }
  return out;
}

/// True when [article]'s title or description contains any of [terms]
/// (expected already normalized via [normalizeMutedTerms]). Pure.
bool articleMatchesMutedTerms(Article article, List<String> terms) {
  if (terms.isEmpty) return false;
  final title = article.title.toLowerCase();
  final description = article.description.toLowerCase();
  for (final term in terms) {
    if (term.isEmpty) continue;
    if (title.contains(term) || description.contains(term)) return true;
  }
  return false;
}
