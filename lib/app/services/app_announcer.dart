import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AppAnnouncer {
  AppAnnouncer._();

  static final AppAnnouncer instance = AppAnnouncer._();
  static const _preferredLanguages = ['en-US', 'en-AU', 'en_AU', 'en_US'];
  static const _screenNames = <String>[
    'Obstacles detection screen',
    'Item detection screen',
    'Sign language translation screen',
    'Noise detection screen',
  ];

  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;
  int? _lastScreenIndex;
  String? _lastTtsError;
  List<String> _engineNames = <String>[];
  int _engineCursor = 0;
  DateTime? _lastObstacleAnnouncementAt;
  String? _lastObstacleAnnouncementText;

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    _flutterTts.setErrorHandler((message) {
      _lastTtsError = '$message';
    });

    await _loadAndSelectEngine();

    final languages = _asStringList(await _flutterTts.getLanguages);
    final selectedLanguage = _selectLanguage(languages);
    if (selectedLanguage != null) {
      await _flutterTts.setLanguage(selectedLanguage);
    }

    try {
      await _flutterTts.setAudioAttributesForNavigation();
    } catch (_) {
      // Not supported on some platforms.
    }

    await _flutterTts.setSpeechRate(0.47);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.awaitSpeakCompletion(true);

    _initialized = true;
  }

  Future<void> _loadAndSelectEngine() async {
    try {
      final enginesDynamic = await _flutterTts.getEngines;
      final engines = _asEngineNames(enginesDynamic);

      if (engines.isEmpty) {
        return;
      }

      _engineNames = engines;
      final preferred = engines.firstWhere(
        (engine) => engine == 'com.google.android.tts',
        orElse: () => engines.first,
      );
      _engineCursor = engines.indexOf(preferred);
      await _flutterTts.setEngine(preferred);
    } catch (_) {
      // Ignore engine selection failure.
    }
  }

  List<String> _asStringList(dynamic values) {
    if (values is! List) {
      return <String>[];
    }
    return values.map((e) => '$e').toList();
  }

  List<String> _asEngineNames(dynamic values) {
    if (values is! List) {
      return <String>[];
    }
    return values
        .map((entry) {
          if (entry is Map && entry['name'] != null) {
            return entry['name'].toString();
          }
          return entry.toString();
        })
        .where((name) => name.trim().isNotEmpty)
        .toList();
  }

  String? _selectLanguage(List<String> languages) {
    for (final candidate in _preferredLanguages) {
      final hasCandidate = languages.any(
        (lang) => lang.toLowerCase() == candidate.toLowerCase(),
      );
      if (hasCandidate) {
        return candidate;
      }
    }

    for (final language in languages) {
      if (language.toLowerCase().startsWith('en')) {
        return language;
      }
    }

    return languages.isNotEmpty ? languages.first : null;
  }

  Future<void> speak(String text, {bool interrupt = true}) async {
    if (text.trim().isEmpty) {
      return;
    }

    await _ensureInitialized();

    if (interrupt) {
      await _flutterTts.stop();
    }

    _lastTtsError = null;
    final result = await _flutterTts.speak(text);
    final isOkResult = result == 1 || result == 0;
    if (!isOkResult || _lastTtsError != null) {
      await _retryWithNextEngine(text, interrupt: interrupt);
    }
  }

  Future<void> _retryWithNextEngine(
    String text, {
    required bool interrupt,
  }) async {
    if (_engineNames.length > 1) {
      _engineCursor = (_engineCursor + 1) % _engineNames.length;
      final nextEngine = _engineNames[_engineCursor];
      try {
        await _flutterTts.setEngine(nextEngine);
      } catch (_) {
        // Ignore engine switch failure.
      }
    } else {
      _initialized = false;
      await _ensureInitialized();
    }

    if (interrupt) {
      await _flutterTts.stop();
    }

    _lastTtsError = null;
    final retryResult = await _flutterTts.speak(text);
    final retryOk =
        (retryResult == 1 || retryResult == 0) && _lastTtsError == null;
    if (!retryOk) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> announceScreenByIndex(int index, {bool force = false}) async {
    if (!force && _lastScreenIndex == index) {
      return;
    }

    if (index < 0 || index >= _screenNames.length) {
      return;
    }

    final screenText = _screenNames[index];
    await speak(screenText);
    _lastScreenIndex = index;
  }

  Future<void> announceCountdownNumber(int value) async {
    await SystemSound.play(SystemSoundType.click);
    await speak('$value');
  }

  Future<void> announceDetectedObjects(
    List<String> objectLabels, {
    required double proximityScore,
    Duration minInterval = const Duration(seconds: 2),
  }) async {
    if (objectLabels.isEmpty) {
      return;
    }

    final cleanedLabels = objectLabels
        .map((label) => _extractObjectName(label))
        .where((label) => label.isNotEmpty)
        .toSet()
        .toList();

    if (cleanedLabels.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final proximityText = _proximityToSpeech(proximityScore);
    final objectText = cleanedLabels.length == 1
        ? cleanedLabels.first
        : '${cleanedLabels.take(2).join(' and ')}${cleanedLabels.length > 2 ? ' and more' : ''}';
    final speechText = '$objectText detected, $proximityText';

    if (_lastObstacleAnnouncementText == speechText &&
        _lastObstacleAnnouncementAt != null &&
        now.difference(_lastObstacleAnnouncementAt!) < minInterval) {
      return;
    }

    _lastObstacleAnnouncementText = speechText;
    _lastObstacleAnnouncementAt = now;

    await speak(speechText, interrupt: false);
  }

  String _extractObjectName(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final confidenceStart = trimmed.lastIndexOf(RegExp(r'\s\d'));
    if (confidenceStart <= 0) {
      return trimmed;
    }

    return trimmed.substring(0, confidenceStart).trim();
  }

  String _proximityToSpeech(double proximityScore) {
    if (proximityScore >= 0.75) {
      return 'very close';
    }
    if (proximityScore >= 0.50) {
      return 'close';
    }
    if (proximityScore >= 0.25) {
      return 'at medium distance';
    }
    return 'far away';
  }
}
