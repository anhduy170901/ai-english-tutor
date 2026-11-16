# 📱 AI English Tutor — Mobile Client (Flutter)

Cross-platform mobile application for the AI English Tutor system, built with **Flutter** to deliver full-duplex, low-latency conversational English practice with a real-time AI tutor.

---

## 🌟 Key Features

- **Full-Duplex Real-time Voice Calls**:
  - Push-To-Talk and hands-free speaking interaction modes.
  - Live token-by-token subtitle streaming.
  - Ultra-smooth, zero-latency audio playback via hardware PCM streaming.
- **Instant Interruption (Barge-in)**:
  - Users can interrupt or start speaking at any moment; previous AI audio synthesis and playback halt immediately.
- **Live Audio Wave Visualizer**:
  - Dynamic audio waveform reacting to microphone input amplitude and AI conversational states (Listening, Thinking, Speaking).
- **CEFR Level & Topic Customization**:
  - Extensive conversational topics (Daily Conversation, Job Interview, Travel, IELTS Speaking, etc.).
  - Adaptable difficulty levels from A1 through C2.
- **Session Review & Summary**:
  - Detailed post-session feedback, mistake reviews with native suggestions, and overall performance metrics.

---

## 🏗️ Architecture & Structure

The mobile application is structured around **Clean Architecture** and the **BLoC pattern**:

```text
mobile/lib/
├── app/                  # App initialization, routes, theme, and global bloc providers
├── core/
│   ├── audio/            # AudioRecorderService (16kHz WAV), AudioPlayerService (Hardware PCM streaming)
│   ├── constants/        # App colors, API endpoints, and SignalR hub URLs
│   ├── di/               # Service locator (GetIt) dependency injection
│   ├── network/          # SignalR Hub client service
│   ├── theme/            # Modern dark theme styling
│   └── utils/            # Logging utilities
└── features/
    ├── session/          # Session management: topic selection, CEFR levels, summary
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    └── voice_tutor/      # Live voice call interface, Push-To-Talk, visualizer, subtitles
        ├── data/
        ├── domain/
        └── presentation/
```

### Core Dependencies

- **`flutter_bloc`**: Predictable state management with clear separation between Events, States, and Business Logic Components.
- **`flutter_pcm_sound`**: Direct hardware feed of raw 24kHz 16-bit Mono PCM audio chunks.
- **`record`**: Microphone capture formatted as 16kHz Mono 16-bit WAV for optimal Whisper STT performance.
- **`signalr_netcore`**: Full-duplex WebSocket communication with the .NET 10 backend.
- **`dio` & `pretty_dio_logger`**: Network client for REST APIs with formatted request logging.
- **`flutter_animate` & `google_fonts`**: Modern UI typography and fluid motion effects.

---

## 🚀 Running the App

### 1. Install Dependencies

```bash
cd mobile
flutter pub get
```

### 2. Configure Backend Host

Host routing is defined in `lib/core/constants/api_constants.dart`:
- **macOS / Web / iOS Simulator**: Automatically connects to `localhost:5129`.
- **Android Emulator**: Automatically routes to `10.0.2.2:5129`.
- **Physical Devices**: Pass the host computer's local Wi-Fi IP via `--dart-define`:
  ```bash
  flutter run --dart-define=BACKEND_HOST=192.168.1.xxx:5129
  ```

### 3. Launch on Target Device

```bash
# Run on default connected device
flutter run

# List all available devices
flutter devices

# Run specifically on macOS or iOS Simulator
flutter run -d macos
flutter run -d "iPhone 16 Pro"
```

---

## 🔒 Permissions

- **Microphone**:
  - **iOS** (`ios/Runner/Info.plist`): Configured with `NSMicrophoneUsageDescription`.
  - **Android** (`android/app/src/main/AndroidManifest.xml`): Declared with `android.permission.RECORD_AUDIO`.
  - **macOS** (`macos/Runner/DebugProfile.entitlements`): Enabled with `com.apple.security.device.audio-input`.
