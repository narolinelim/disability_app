import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/noise_detection_config.dart';

class NoiseTensorflowService {
	const NoiseTensorflowService._();

	static const yamNet = NoiseTensorflowService._();

	static late final Interpreter _interpreter;
	static late final List<String> _labels;
	static bool _initialized = false;

	Interpreter get interpreter => _interpreter;
	List<String> get labels => _labels;

	Future<void> initialize() async {
		if (_initialized) {
			return;
		}

		await Future.wait([
			_loadModel(),
			_loadLabels(),
		]);

		_initialized = true;
	}

	Future<void> _loadModel() async {
		final options = InterpreterOptions()
			..threads = NoiseDetectionConfig.intraOpThreads;
		_interpreter = await Interpreter.fromAsset(
			NoiseDetectionConfig.modelAssetPath,
			options: options,
		);
	}

	Future<void> _loadLabels() async {
		final csv = await rootBundle.loadString(NoiseDetectionConfig.labelsAssetPath);
		final rows = csv.split(RegExp(r'\r?\n'));

		final labels = <String>[];
		for (final row in rows.skip(1)) {
			final line = row.trim();
			if (line.isEmpty) {
				continue;
			}

			final firstComma = line.indexOf(',');
			final secondComma = firstComma < 0 ? -1 : line.indexOf(',', firstComma + 1);
			if (firstComma < 0 || secondComma < 0 || secondComma == line.length - 1) {
				continue;
			}

			var displayName = line.substring(secondComma + 1).trim();
			if (displayName.startsWith('"') && displayName.endsWith('"')) {
				displayName = displayName.substring(1, displayName.length - 1);
			}
			labels.add(displayName.replaceAll('""', '"'));
		}

		_labels = labels;
	}
}
