# 🎙️ AI English Tutor — Real-time Voice-to-Voice AI Tutoring System

An intelligent English tutoring platform featuring bidirectional, real-time voice communication (Voice-to-Voice) with ultra-low latency (< 1 second). The system emulates natural spoken dialogue akin to calling a native English tutor (IELTS 8.5+), offering immediate grammar corrections, vocabulary enhancements, and CEFR-aligned learning evaluations.

---

## 📑 Table of Contents
- [Architecture Overview](#-architecture-overview)
- [Key Features](#-key-features)
- [Tech Stack](#-tech-stack)
- [Repository Structure](#-repository-structure)
- [Prerequisites](#-prerequisites)
- [Getting Started](#-getting-started)
  - [1. Infrastructure Services (Docker)](#1-infrastructure-services-docker)
  - [2. Local LLM Setup (Ollama)](#2-local-llm-setup-ollama)
  - [3. Run Backend API (.NET 10)](#3-run-backend-api-net-10)
  - [4. Run Mobile App (Flutter)](#4-run-mobile-app-flutter)
- [Real-time Audio Pipeline](#-real-time-audio-pipeline)
- [API & SignalR Reference](#-api--signalr-reference)
- [Troubleshooting & FAQs](#-troubleshooting--faqs)
- [License](#-license)

---

## 🏛️ Architecture Overview

The repository is structured as a Monorepo containing two core sub-systems:
- **Backend**: Built with **.NET 10** following **Clean Architecture**, **CQRS (MediatR)**, and **ASP.NET Core SignalR** for real-time bidirectional duplex communication.
- **Mobile**: Cross-platform application built with **Flutter (iOS/Android/macOS)** utilizing **Clean Architecture** and the **BLoC pattern**, directly streaming uncompressed PCM audio chunks into hardware audio buffers.

### Real-time Audio Pipeline Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    actor User as User [Flutter App]
    participant Hub as SignalR VoiceHub [.NET 10]
    participant STT as Whisper.net [STT]
    participant LLM as Ollama [Llama 3.2]
    participant TTS as Edge TTS / Kokoro [TTS]
    participant DB as PostgreSQL [Write/Read DB]

    User->>Hub: Stream audio (16kHz Mono WAV via ProcessUserAudio)
    Hub->>STT: Transcribe speech to text
    STT-->>Hub: User transcribed text
    Hub-->>User: Dispatch UserTranscribedText event (instant display)
    Hub->>DB: Persist User message (CQRS Write)

    Hub->>LLM: Stream prompt with IELTS Tutor context
    loop Token Streaming & Sentence Breaking
        LLM-->>Hub: Yield token
        Hub-->>User: Dispatch ReceiveSubtitleToken (real-time subtitles)
        opt Reached sentence end (. ? !) or clause boundary (, ; : with 4+ words)
            Hub->>TTS: Synthesize raw PCM chunk (raw-24khz-16bit-mono)
            TTS-->>Hub: Yield PCM byte chunks
            Hub-->>User: Dispatch ReceiveAudioChunk (streamed to speaker)
        end
    end

    Hub->>DB: Persist Tutor response (CQRS Write)
    Hub-->>User: Dispatch TurnCompleted event
```

---

## ✨ Key Features

1. **Full-Duplex Real-time Voice Conversation**:
   - Sub-second voice response latency (< 1s) achieved through **Raw PCM Streaming** directly fed into hardware sound buffers without waiting for full sentences or saving temporary audio files.
2. **Instant Interruption / Barge-in Support**:
   - Users can speak over the AI or trigger a new turn at any point. The backend instantly cancels the previous LLM token generation and TTS audio synthesis via `CancellationToken`, while the client flushes its active audio buffer.
3. **Pedagogical Prompting & Natural Corrections**:
   - Calibrated for IELTS 8.5+ conversational style: concise responses (1–3 sentences), natural conversational cadence, gentle inline corrections: `(Tip: Instead of "...", you can say "...")`, ending with open-ended questions.
4. **CEFR Level Progression**:
   - Fully adaptable across **A1, A2, B1, B2, C1, and C2** proficiency levels, tailoring vocabulary complexity and speaking pace to the learner.
5. **Privacy-First & Fully Local AI Support**:
   - **Speech-to-Text**: Native local OpenAI Whisper via `Whisper.net` (auto-downloads and caches GGML models locally).
   - **LLM**: Local execution using **Ollama** (defaulting to `llama3.2:latest`).
   - **TTS**: High-fidelity Microsoft Edge TTS or 100% offline local **Kokoro TTS** via Docker.
6. **Session Evaluation & Analytics**:
   - Complete conversation transcript history, feedback reports, and CEFR progress evaluation upon session completion.

---

## 🛠️ Tech Stack

### Backend (.NET 10)
| Technology | Role |
|---|---|
| **.NET 10 Web API** | High-performance backend runtime and REST APIs |
| **Clean Architecture** | Decoupled layers: `Domain`, `Application`, `Infrastructure`, `Persistence`, `API` |
| **MediatR (CQRS)** | Segregation of Commands (Write) and Queries (Read) |
| **ASP.NET Core SignalR** | Real-time WebSocket hub for token & audio streaming |
| **Whisper.net** | Local Speech-to-Text powered by native GGML Whisper models |
| **OllamaSharp** | Async streaming client for local Ollama LLM execution |
| **Npgsql & EF Core 10** | PostgreSQL ORM with dedicated Write and Read DbContexts |
| **Serilog** | Structured console logging with correlation Activity Trace IDs |
| **Scalar** | Modern API reference documentation UI (`/scalar/v1`) |

### Mobile (Flutter)
| Package | Role |
|---|---|
| **Flutter 3.x / Dart 3** | Cross-platform UI toolkit (iOS, Android, macOS) |
| **flutter_bloc** | Predictable state management following BLoC architecture |
| **get_it** | Service locator for dependency injection |
| **record** | Microphone recording configured for 16kHz Mono 16-bit WAV |
| **flutter_pcm_sound** | Direct feed of raw 24kHz PCM chunks to device audio output |
| **signalr_netcore** | Bidirectional SignalR WebSocket client |
| **dio & pretty_dio_logger** | Resilient REST HTTP client with request logging |
| **flutter_animate** | Fluid micro-interactions and audio wave visualization |

---

## 📁 Repository Structure

```text
ai-english-tutor/
├── backend/
│   ├── src/
│   │   ├── AiEnglishTutor.Domain/          # Core entities, enums (LearningSession, SessionMessage, CefrLevel)
│   │   ├── AiEnglishTutor.Application/     # CQRS Commands, Queries, DTOs, interface abstractions
│   │   ├── AiEnglishTutor.Infrastructure/  # Whisper STT, Ollama LLM, Edge & Kokoro TTS, Prompts
│   │   ├── AiEnglishTutor.Persistence/     # EF Core, PostgreSQL DbContexts (Write/Read), Repositories
│   │   └── AiEnglishTutor.API/             # Controllers, SignalR VoiceHub, Program.cs, Scalar OpenAPI
│   ├── docker-compose.yml                  # PostgreSQL 16 & Kokoro TTS services
│   ├── AiEnglishTutor.sln                  # Visual Studio / Rider Solution file
│   ├── CODE_REVIEW.md                      # Code audit, security fixes, and architectural notes
│   └── PCM_STREAMING_PLAN.md               # Backend PCM streaming implementation spec
│
└── mobile/
    ├── lib/
    │   ├── app/                            # App initialization, theming, and global bloc providers
    │   ├── core/                           # Audio services, SignalR client, constants, theme, DI
    │   └── features/
    │       ├── session/                    # Topic selection, CEFR levels, session summary
    │       └── voice_tutor/                # Voice call screen, Push-to-Talk, audio visualizer, subtitles
    ├── pubspec.yaml                        # Flutter package configuration
    └── PCM_STREAMING_PLAN.md               # Mobile PCM streaming implementation spec
```

---

## 💻 Prerequisites

- **Operating System**: macOS, Linux, or Windows 11.
- **.NET SDK**: Version `10.0` or higher.
- **Flutter SDK**: Version `>= 3.3.1` (with Xcode for iOS/macOS or Android Studio for Android).
- **Docker & Docker Compose**: For PostgreSQL and optional Kokoro TTS containers.
- **Ollama**: Installed locally with the `llama3.2:latest` model pulled.

---

## 🚀 Getting Started

### 1. Infrastructure Services (Docker)

Navigate to the `backend/` directory and launch the background containers:

```bash
cd backend
docker compose up -d
```

> **Note**: This starts:
> - **PostgreSQL 16**: Port `5433` (User: `postgres`, Password: `postgrespassword`, Database: `ai_tutor_db`).
> - **Kokoro TTS (CPU)**: Port `8880` (Optional offline Text-to-Speech service).

Verify running containers:
```bash
docker compose ps
```

---

### 2. Local LLM Setup (Ollama)

Ensure the Ollama daemon is running at `http://127.0.0.1:11434`, then pull the Llama 3.2 model:

```bash
# Pull model (first run only)
ollama pull llama3.2

# Verify execution
ollama run llama3.2 "Hello"
```

---

### 3. Run Backend API (.NET 10)

1. Verify settings in `backend/src/AiEnglishTutor.API/appsettings.json`:
   ```json
   {
     "ConnectionStrings": {
       "DefaultConnection": "Host=localhost;Port=5433;Database=ai_tutor_db;Username=postgres;Password=postgrespassword"
     },
     "Ollama": {
       "Endpoint": "http://127.0.0.1:11434",
       "Model": "llama3.2:latest"
     },
     "Tts": {
       "Provider": "Edge",
       "DefaultVoice": "af_heart"
     }
   }
   ```

2. Start the API service:
   ```bash
   cd backend/src/AiEnglishTutor.API
   dotnet run
   ```

3. The backend will:
   - Auto-create PostgreSQL database schema if missing (`EnsureCreated`).
   - Automatically download the Whisper STT model (`ggml-base.en.bin` ~140MB) into `~/.ai-english-tutor/models/` if not present.
   - Listen for HTTP & SignalR connections at: `http://localhost:5129`.
   - Expose the Scalar API documentation at: `http://localhost:5129/scalar/v1`.

---

### 4. Run Mobile App (Flutter)

1. Open a new terminal and navigate to `mobile/`:
   ```bash
   cd mobile
   flutter pub get
   ```

2. **Backend Host Configuration**:
   - **iOS Simulator / macOS**: Automatically connects to `localhost:5129`.
   - **Android Emulator**: Automatically routes to `10.0.2.2:5129`.
   - **Physical Devices**: Pass your machine's LAN IP address via `--dart-define`:
     ```bash
     flutter run --dart-define=BACKEND_HOST=192.168.1.xxx:5129
     ```
     *(Replace `192.168.1.xxx` with your local development machine IP)*.

3. Launch the application:
   ```bash
   flutter run
   ```

---

## ⚡ Real-time Audio Pipeline

The system achieves sub-second conversational latency through four architectural optimizations:

1. **Optimized Client-side Recording**:
   - Audio is recorded at **16,000 Hz, 16-bit Mono WAV** format using `record`. This matches Whisper's native expected input sample format directly, avoiding audio transcoding overhead.

2. **Clause-Level Chunking & Pipelining**:
   - As Ollama streams LLM tokens, the backend analyzes sentence boundaries:
     - Sentence end punctuation: `.`, `?`, `!`, `\n`.
     - Clause boundaries: `,`, `;`, `:` when the phrase length reaches $\ge 4$ words.
   - Once a clause boundary is detected, the phrase is immediately dispatched to TTS synthesis while the LLM continues generating subsequent tokens in parallel.

3. **Raw Uncompressed PCM Streaming (24kHz, 16-bit, Mono)**:
   - Audio is transmitted as raw `raw-24khz-16bit-mono-pcm` chunks. Unlike MP3/AAC, raw PCM carries no container headers, allowing immediate byte streaming over SignalR.
   - The backend enforces strict 2-byte sample alignment (16-bit mono) before yielding network packets to prevent phase-shift distortion.
   - Flutter's `flutter_pcm_sound` pushes `Int16List` buffers directly to audio hardware buffers.

4. **Barge-in & Turn Management**:
   - Every conversational turn carries a unique `turnId`.
   - When the user starts speaking, the backend cancels the active `CancellationToken` of any running turn, terminating LLM token emission and TTS synthesis immediately.
   - The mobile client purges its local playback queue upon barge-in, preventing stale audio overlap.

---

## 🔌 API & SignalR Reference

### REST Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/sessions` | Create a new learning session (`Topic`, `TargetLevel`) |
| `GET` | `/api/sessions/{id}` | Retrieve complete conversation history for a session |
| `GET` | `/api/sessions/active` | List all currently active sessions |
| `POST` | `/api/sessions/{id}/complete` | Conclude session with evaluation feedback |
| `POST` | `/api/test/chat` | Test Ollama chat generation (Dev only) |
| `POST` | `/api/test/tts` | Test TTS synthesis returning WAV audio (Dev only) |

### SignalR Hub (`/hubs/voice`)

#### Client Invocations:
- `StartSession(string topic, CefrLevel level)`: Initializes and binds a session to the connection.
- `JoinSession(Guid sessionId)`: Binds an existing active session upon reconnect.
- `ProcessUserAudio(byte[] audioBytes, Guid turnId, Guid? sessionId)`: Submits audio recording for processing.
- `ProcessUserText(string userText, Guid turnId, Guid? sessionId)`: Submits typed text input.

#### Server Dispatches:
- `StatusUpdate(string status)`: Progress status ("Transcribing speech...", "AI is thinking...").
- `UserTranscribedText(string text)`: Transcribed user input from STT.
- `ReceiveSubtitleToken(string token, Guid turnId)`: Incremental AI response token for live subtitle display.
- `ReceiveAudioChunk(byte[] pcmChunk, Guid turnId)`: Raw PCM audio slice streamed to device audio feed.
- `TurnCompleted(string fullResponse)`: Signals completion of the current conversational turn.

---

## ❓ Troubleshooting & FAQs

1. **No audio heard on physical device or simulator**:
   - Ensure microphone and speaker permissions are granted.
   - On iOS devices, verify that the physical Silent/Mute switch is turned off.
2. **SignalR connection failures from physical mobile devices**:
   - Ensure the mobile device and development workstation are on the same Wi-Fi subnet.
   - Check local firewall rules for port `5129`.
   - Launch with the explicit host IP: `--dart-define=BACKEND_HOST=<LAN_IP>:5129`.
3. **Whisper model download delays on initial startup**:
   - On first launch, the backend downloads `ggml-base.en.bin` (~140MB). Wait until the console logs `Whisper model downloaded successfully` before starting voice calls.
4. **Ollama connection errors**:
   - Verify that Ollama is active (`curl http://127.0.0.1:11434/api/tags`) and that `llama3.2:latest` is installed.

---

## 📄 License

This project is licensed under the MIT License — developed for research, education, and conversational AI tutoring applications.
