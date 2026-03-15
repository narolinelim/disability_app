/*
 * Pipeline location: app/feature/noise_detection/noise_detection.dart (Step 8 of 8)
 * General function: Feature host UI that binds controller state/results and renders user-facing noise feedback.
 * Return/output: Stateful widget that displays live status, latest classification, and warning styling.
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_announcer.dart';
import '../../widgets/module_bottom_sheet.dart';
import '../../widgets/module_header.dart';
import 'controllers/noise_detection_controller.dart';
import 'models/noise_detection_models.dart';
import 'package:vibration/vibration.dart';



class NoiseDetectionHost extends StatefulWidget {
	const NoiseDetectionHost({super.key});

	@override
	State<NoiseDetectionHost> createState() => _NoiseDetectionHostState();
}

class _NoiseDetectionHostState extends State<NoiseDetectionHost> {
	late final NoiseDetectionController _controller;
	StreamSubscription<NoiseFrameResult>? _resultsSubscription;
	String? _latestResult;
	bool _latestIsWarning = false;
	DateTime? _lastAnnouncementAt;

	@override
	void initState() {
		super.initState();
		_controller = NoiseDetectionController();

		// Listen to detection frames and convert dangerous predictions into visible alerts.
		_resultsSubscription = _controller.resultsStream.listen((result) {
			if (!mounted || result.prediction == null) {
				return;
			}

			final prediction = result.prediction!;
			final displayText =
					'${prediction.label} (${(prediction.confidence * 100).toStringAsFixed(0)}%) - ${result.decibel.toStringAsFixed(1)} dB';
			final rowText = result.isDanger
					? 'WARNING: $displayText'
					: displayText;
      
			setState(() {
				_latestResult = rowText;
				_latestIsWarning = result.isDanger;
			});

      // List of sounds that needs to be vibrated
      final List<String> vibrateSounds = ['Siren', 'Smoke alarm', 'Fire alarm', 'Smoke detector', 'Alarm', 'Car alarm', 'Car horn', 'Gunshot', 'Explosion', 'Baby crying', 'Dog barking', 'Bicycle bell'];

			if (result.isDanger && vibrateSounds.contains(prediction.label)) {
				// Vibrate
        Vibration.vibrate(duration: 1000); // Vibrates for 1 second
			}
      else{
        return;
      }
		});

		unawaited(_controller.start());
	}

	@override
	void dispose() {
		unawaited(_resultsSubscription?.cancel());
		unawaited(_controller.dispose());
		super.dispose();
	}

	Future<void> _toggleListening(bool isListening) async {
		if (isListening) {
			await _controller.pause();
			await AppAnnouncer.instance.speak('Noise monitoring paused.');
			return;
		}

		await _controller.resume();
		await AppAnnouncer.instance.speak('Noise monitoring on.');
	}

	@override
	Widget build(BuildContext context) {
		// Bind controller state to UI so status text updates as new frames arrive.
		return ValueListenableBuilder<NoiseUiState>(
			valueListenable: _controller.uiState,
			builder: (context, state, _) {
				return Column(
					children: [
						const ModuleHeader(
							title: 'Noise Detection',
							accent: Color(0xFFEA580C),
						),
						Expanded(
							child: Container(
								width: double.infinity,
								margin: const EdgeInsets.symmetric(horizontal: 10),
								padding: const EdgeInsets.all(24),
								decoration: const BoxDecoration(
									gradient: LinearGradient(
										begin: Alignment.topCenter,
										end: Alignment.bottomCenter,
										colors: [Color(0xFFFFF7ED), Colors.white],
									),
								),
								child: Column(
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										GestureDetector(
											onTap: () => _toggleListening(state.isListening),
											child: AnimatedContainer(
												duration: const Duration(milliseconds: 350),
												width: 96,
												height: 96,
												decoration: BoxDecoration(
													shape: BoxShape.circle,
													color: state.isListening
															? const Color(0xFFDCFCE7)
															: const Color(0xFFE5E7EB),
												),
												child: Icon(
													Icons.volume_up_outlined,
													size: 48,
													color: state.isListening
															? const Color(0xFF16A34A)
															: const Color(0xFF9CA3AF),
												),
											),
										),
										const SizedBox(height: 22),
										Text(
											state.isListening
													? 'Listening for Sounds'
													: 'Monitoring Paused',
											style: const TextStyle(
												color: Color(0xFF111827),
												fontSize: 20,
												fontWeight: FontWeight.w700,
											),
										),
										const SizedBox(height: 10),
										Text(
											state.error != null
													? state.error!
													: state.isListening
															? 'Actively monitoring environmental sounds'
															: 'Tap center icon to resume monitoring',
											textAlign: TextAlign.center,
											style: TextStyle(
												color: state.error != null
														? const Color(0xFFB91C1C)
														: const Color(0xFF4B5563),
												fontSize: 14,
											),
										),
										const SizedBox(height: 16),
										Text(
											state.lastDecibel == null
													? (state.isModelReady
															? 'Model ready'
															: 'Loading noise model...')
													// Live dB result rendered here from controller uiState.
													: 'Current level: ${state.lastDecibel!.toStringAsFixed(1)} dB',
											style: const TextStyle(
												color: Color(0xFF6B7280),
												fontSize: 13,
											),
										),
										const SizedBox(height: 8),
										Text(
											state.lastLabel == null
													? 'Detected sound: -'
													: 'Detected sound: ${state.lastLabel}',
											style: const TextStyle(
												color: Color(0xFF374151),
												fontSize: 13,
											),
										),
									],
								),
							),
						),
						ModuleBottomSheet(
							title: 'Noise Result',
							accent: const Color(0xFFFED7AA),
							hasData: _latestResult != null,
							child: _latestResult == null
									? const Padding(
											padding: EdgeInsets.only(top: 6),
											child: Text(
												'No noise result yet',
												style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
											),
										)
									: Container(
											width: double.infinity,
											margin: const EdgeInsets.only(bottom: 10),
											padding: const EdgeInsets.all(12),
											decoration: BoxDecoration(
												color: _latestIsWarning
														? const Color(0xFFFFE4E6)
														: const Color(0xFFFFF7ED),
												borderRadius: BorderRadius.circular(12),
												border: Border.all(
													color: _latestIsWarning
															? const Color(0xFFFDA4AF)
															: const Color(0xFFFED7AA),
												),
											),
											child: Text(
												_latestResult!,
												style: TextStyle(
													color: _latestIsWarning
															? const Color(0xFF9F1239)
															: const Color(0xFF7C2D12),
													fontSize: 14,
												),
											),
									),
						),
					],
				);
			},
		);
	}
}
