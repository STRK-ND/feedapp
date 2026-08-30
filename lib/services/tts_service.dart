/// Listen mode — text-to-speech for the in-app reader.
///
/// Wraps flutter_tts with:
/// - sentence-boundary chunking (TTS engines choke on very long strings);
/// - sequential playback driven by `awaitSpeakCompletion`, with a
///   generation counter so stop()/restart reliably cancels stale loops;
/// - pause/resume: Android pauses natively (plugin workaround, SDK >= 26);
///   resume continues from the START of the current chunk everywhere,
///   which is deterministic even when the native mid-sentence resume
///   is unavailable.
///
/// Extends [ChangeNotifier]; the reader owns all UI.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { stopped, playing, paused }

class TtsService extends ChangeNotifier {
  TtsService({FlutterTts? engine}) : _engineOrNull = engine;

  final FlutterTts? _engineOrNull;
  FlutterTts? _prepared;

  TtsState _state = TtsState.stopped;
  TtsState get state => _state;

  /// Index of the chunk currently being spoken (for progress UI).
  int get currentChunk => _chunkIndex;
  int get chunkCount => _chunks.length;
  int _chunkIndex = 0;
  List<String> _chunks = const [];

  // Bumped by stop()/speak()/resume() so an in-flight chunk loop from a
  // previous session aborts instead of fighting the new one.
  int _generation = 0;

  Future<FlutterTts> _prepare() async {
    final existing = _prepared;
    if (existing != null) return existing;
    final tts = _engineOrNull ?? FlutterTts();
    await tts.setLanguage('en-US');
    // Platform-normalized scale 0.0–1.0; ~0.45 is natural reading pace.
    await tts.setSpeechRate(0.45);
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);
    await tts.awaitSpeakCompletion(true);
    _prepared = tts;
    return tts;
  }

  /// Split [text] into TTS-sized chunks at sentence boundaries. Pure and
  /// deterministic so tests can pin the contract.
  static List<String> chunkText(String text, {int maxChars = 2800}) {
    if (text.trim().isEmpty) return const [];
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) return [normalized];

    final chunks = <String>[];
    var remaining = normalized;
    while (remaining.length > maxChars) {
      final window = remaining.substring(0, maxChars);
      // Prefer the last sentence end inside the window; degrade to comma,
      // then any space, then a hard cut.
      var cut = window.lastIndexOf('. ');
      if (cut < maxChars ~/ 2) cut = window.lastIndexOf(', ');
      if (cut < maxChars ~/ 2) cut = window.lastIndexOf(' ');
      if (cut <= 0) {
        chunks.add(window);
        remaining = remaining.substring(maxChars);
      } else {
        chunks.add(window.substring(0, cut + 1).trim());
        remaining = remaining.substring(cut + 1).trim();
      }
    }
    if (remaining.isNotEmpty) chunks.add(remaining);
    return chunks;
  }

  /// Speak [text] (title + body). Safe to call while already playing —
  /// restarts with the new content.
  Future<void> speak(String text) async {
    await stop();
    final chunks = chunkText(text);
    if (chunks.isEmpty) return;
    _chunks = chunks;
    final gen = ++_generation;
    await _playFrom(0, gen);
  }

  Future<void> _playFrom(int startIndex, int gen) async {
    final tts = await _prepare();
    _state = TtsState.playing;
    notifyListeners();

    for (var i = startIndex; i < _chunks.length; i++) {
      if (_generation != gen || _state == TtsState.stopped) return;
      _chunkIndex = i;
      notifyListeners();
      try {
        await tts.speak(_chunks[i]);
      } catch (e) {
        debugPrint('[Tts] speak failed: $e');
        _state = TtsState.stopped;
        notifyListeners();
        return;
      }
      // A pause during this chunk leaves the plugin mid-utterance; hand
      // control back and let resume() continue from this chunk.
      if (_state == TtsState.paused) return;
    }
    if (_generation == gen && _state == TtsState.playing) {
      _state = TtsState.stopped;
      _chunkIndex = 0;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (_state != TtsState.playing) return;
    _state = TtsState.paused; // set first: the playing loop checks it
    notifyListeners();
    try {
      await _prepared?.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (_state != TtsState.paused || _chunks.isEmpty) return;
    final index = _chunkIndex.clamp(0, _chunks.length - 1).toInt();
    final gen = ++_generation;
    await _playFrom(index, gen);
  }

  Future<void> stop() async {
    _generation++;
    _state = TtsState.stopped;
    _chunkIndex = 0;
    notifyListeners();
    try {
      await _prepared?.stop();
    } catch (_) {}
  }

  @override
  String toString() =>
      'TtsService(state: $_state, chunk $_chunkIndex/${_chunks.length})';
}
