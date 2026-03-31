# SenseBridge: Disability Assistance App

SenseBridge is a Flutter-based mobile application designed to assist people with disabilities by leveraging real-time sign language (Auslan) translation, obstacle detection, and noise detection. The app uses on-device machine learning models and device sensors to provide accessible, multimodal feedback.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Assets & Models](#assets--models)
- [Contributing](#contributing)
- [License](#license)

## Features

### 1. Sign Language (Auslan) Translation
- Uses the device camera and a TFLite model to recognize Auslan hand signs in real time.
- Translates detected signs into text and displays the result.

### 2. Obstacle Detection
- Detects obstacles using the camera and a YOLO-based TFLite model.
- Provides visual and audio feedback to help users navigate safely.

### 3. Noise Detection
- Monitors environmental noise using the microphone and a sound classification model.
- Alerts users to dangerous or important sounds with vibration and on-screen warnings.

## Installation

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (Dart 3.11.1+)
- Android Studio or Xcode for device emulation or deployment
- Device with camera, microphone, and vibration support recommended

### Steps
1. **Clone the repository:**
	 ```sh
	 git clone <repo-url>
	 cd disability_app
	 ```
2. **Install dependencies:**
	 ```sh
	 flutter pub get
	 ```
3. **Add environment variables:**
	 - Copy `.env.example` to `.env` and fill in any required keys (if applicable).
4. **Run the app:**
	 ```sh
	 flutter run
	 ```

## Usage

On launch, SenseBridge presents a navigation bar to access its three main modules:

- **Sign Language Translation:**
	- Point the camera at Auslan hand signs to see real-time translation.
- **Obstacle Detection:**
	- Use the camera to detect obstacles in your path. The app provides feedback to help avoid hazards.
- **Noise Detection:**
	- The app listens for environmental sounds and alerts you to important or dangerous noises.

All modules are accessible from the main navigation bar. The app is optimized for portrait mode and dark theme.

## Project Structure

```
lib/
	main.dart                # App entry point
	app/
		sense_bridge_home.dart # Main navigation and screen host
		screens/               # UI screens for each feature
		feature/               # Feature logic and ML integration
		widgets/               # Reusable UI components
assets/
	auslan_detection/        # Auslan TFLite model
	obstacle/                # Obstacle detection models and labels
	noise_detection/         # Noise detection model and CSVs
backend/                   # (Optional) Python backend for model serving
```

## Assets & Models

The app uses several on-device TFLite models and CSV label files. These are included in the `assets/` directory and referenced in `pubspec.yaml`.

If you add or update models, ensure to update the asset paths in `pubspec.yaml`.

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch
3. Commit your changes with clear messages
4. Open a pull request

Please follow Dart/Flutter best practices and ensure all code passes analysis and tests.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
