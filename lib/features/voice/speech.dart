import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Turns speech into text with the platform's recognizer.
abstract class SpeechInput {
  /// Asks for the microphone and speech permissions on first use. False
  /// when recognition can't be used on this device.
  Future<bool> available();

  /// Listens until the speaker pauses and returns what they said, or null
  /// when nothing was recognized. [onPartial] gets the words so far.
  Future<String?> listen({
    required String localeTag,
    void Function(String words)? onPartial,
  });

  Future<void> stop();

  /// Why the last [listen] stopped early, such as the recognizer failing
  /// to start. Null when it ended normally.
  String? get lastError;
}

/// Reads text aloud with the platform's voice.
abstract class SpeechOutput {
  /// Completes when the text has been spoken or [stop] was called.
  Future<void> speak(String text, {required String localeTag});

  Future<void> stop();
}

class PlatformSpeechInput implements SpeechInput {
  final _speech = SpeechToText();
  Completer<String?>? _pending;
  String _words = '';

  @override
  String? lastError;

  @override
  Future<bool> available() async {
    try {
      return await _speech.initialize(
        onStatus: (status) {
          if (status == SpeechToText.doneStatus ||
              status == SpeechToText.notListeningStatus) {
            _finish();
          }
        },
        onError: (error) {
          lastError = error.errorMsg;
          _finish();
        },
      );
    } catch (_) {
      return false;
    }
  }

  void _finish() {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    final words = _words.trim();
    pending.complete(words.isEmpty ? null : words);
  }

  @override
  Future<String?> listen({
    required String localeTag,
    void Function(String words)? onPartial,
  }) async {
    _finish();
    final pending = _pending = Completer<String?>();
    _words = '';
    lastError = null;
    await _speech.listen(
      onResult: (result) {
        _words = result.recognizedWords;
        onPartial?.call(_words);
        if (result.finalResult) _finish();
      },
      listenOptions: SpeechListenOptions(
        localeId: localeTag.replaceAll('-', '_'),
        listenFor: const Duration(minutes: 1),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
    return pending.future;
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
    _finish();
  }
}

class PlatformSpeechOutput implements SpeechOutput {
  final _tts = FlutterTts();
  bool _ready = false;

  @override
  Future<void> speak(String text, {required String localeTag}) async {
    if (!_ready) {
      await _tts.awaitSpeakCompletion(true);
      _ready = true;
    }
    await _tts.setLanguage(localeTag);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

final speechInputProvider = Provider<SpeechInput>(
  (ref) => PlatformSpeechInput(),
);

final speechOutputProvider = Provider<SpeechOutput>(
  (ref) => PlatformSpeechOutput(),
);

/// The speech locale for an app language.
String speechLocaleTag(String languageCode) =>
    languageCode == 'ja' ? 'ja-JP' : 'en-US';
