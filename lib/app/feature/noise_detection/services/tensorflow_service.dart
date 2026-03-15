/*
 * Pipeline location: app/feature/noise_detection/services/tensorflow_service.dart (Step 3 of 8)
 * General function: Loads and caches the YAMNet TFLite interpreter and class labels from assets.
 * Return/output: initialize() prepares interpreter/labels for downstream classification.
 */
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/noise_detection_config.dart';
import '../models/noise_detection_models.dart';

class NoiseTensorflowService {
	const NoiseTensorflowService._();

	static const yamNet = NoiseTensorflowService._();

	static late final Interpreter _interpreter;
	static late final List<NoiseClassInfo> _classMap;
	static bool _initialized = false;

	Interpreter get interpreter => _interpreter;
	List<NoiseClassInfo> get classMap => _classMap;

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

	// Loads the TFLite model from bundled assets and creates the interpreter.
	Future<void> _loadModel() async {
		final options = InterpreterOptions()
			..threads = NoiseDetectionConfig.intraOpThreads;
		_interpreter = await Interpreter.fromAsset(
			NoiseDetectionConfig.modelAssetPath,
			options: options,
		);
	}

	// Loads the CSV label file and builds a class index to metadata map.
	Future<void> _loadLabels() async {
		final csv = await rootBundle.loadString(NoiseDetectionConfig.labelsAssetPath);
		final rows = csv.split(RegExp(r'\r?\n'));

		final map = List<NoiseClassInfo>.generate(
			NoiseDetectionConfig.modelOutputClasses,
			(index) => NoiseClassInfo(
				index: index,
				mid: '/m/unknown_$index',
				displayName: 'Unknown sound',
			),
		);

		// CSV rows are formatted like: index,mid,"display_name".
		// We split by the first two commas so display names can safely contain commas.
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

			final index = int.tryParse(line.substring(0, firstComma).trim());
			if (index == null || index < 0 || index >= map.length) {
				continue;
			}

			final mid = line.substring(firstComma + 1, secondComma).trim();

			var displayName = line.substring(secondComma + 1).trim();
			// Remove wrapping quotes and unescape doubled quotes from CSV format.
			if (displayName.startsWith('"') && displayName.endsWith('"')) {
				displayName = displayName.substring(1, displayName.length - 1);
			}

			map[index] = NoiseClassInfo(
				index: index,
				mid: mid,
				displayName: displayName.replaceAll('""', '"'),
			);
		}

		_classMap = map;
	}
}
