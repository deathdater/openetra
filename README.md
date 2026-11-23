<p align="center">
  <img src="assets/branding/openetra_logo.png" alt="Openetra Logo" width="140" />
</p>

<h1 align="center">Openetra</h1>

<p align="center">
  <strong>Offline-First, Low-Power AI Visual Assistance Platform for Android</strong><br/>
  Designed for people who are blind or have low vision — voice-first, TalkBack-ready, private by design.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android%20(arm64--v8a)-3DDC84?logo=android&logoColor=white" alt="Android arm64-v8a" />
  <img src="https://img.shields.io/badge/Framework-Flutter%20%26%20Kotlin-02569B?logo=flutter&logoColor=white" alt="Flutter and Kotlin" />
  <img src="https://img.shields.io/badge/Processing-100%25%20On--Device-6A1B9A" alt="100% On-Device" />
  <img src="https://img.shields.io/badge/Accessibility-WCAG%20AAA%20%7C%20TalkBack-00897B" alt="WCAG AAA" />
  <img src="https://img.shields.io/badge/Languages-8%20Indian%20%2B%20English-F57C00" alt="8 Languages" />
</p>

---

## 🌟 Product Vision

**Openetra** helps blind and severely visually impaired users understand their surroundings and complete everyday visual tasks independently on affordable Android smartphones — **without requiring an internet connection** for core assistive workflows.

- **Offline-First & Private:** Scene understanding, OCR, object memory, speech, haptics, and emergency contacts run locally on-device with zero telemetry and zero cloud inference.
- **Voice-First & Eyes-Free:** Every screen, radial dial menu, error, and permission prompt is spoken aloud and engineered for TalkBack and tactile haptic confirmation.
- **Honest Safety Boundaries:** Openetra communicates AI uncertainty clearly. It is an assistive aid and **never replaces a white cane, guide dog, or mobility training**, and never guarantees a road is safe to cross.

---

## ✨ Key Features

| Icon | Feature | Description |
| :---: | :--- | :--- |
| 👁️ | **Scene Understanding & Continuous Mode** | On-device Mirage VLM describes surroundings, supports multi-frame scene recording with editable multilingual notes, and proactively calls out registered personal items when recognized with confidence. |
| 📖 | **Smart Reader (Offline OCR)** | Reads printed signs, labels, and documents offline using Google ML Kit Devanagari and Tesseract4Android across English and 7 Indian scripts. |
| 🔎 | **Personal Object Memory** | Register personal items (keys, wallet, bottle, etc.) locally on-device. Uses visual embeddings with strict semantic gating to locate registered items without false positives, and records last-seen context. |
| ⚠️ | **Hazard Awareness Cues** | Scans the camera view for potential obstacles and hazards with explicit uncertainty notices and safety policy filtering. |
| 💵 | **Currency & Product Assistant** | Offline Indian Rupee denomination recognition (with non-counterfeit disclaimer) and offline ML Kit barcode/product scanning. |
| 🎛️ | **Assistive Radial Dial & Voice Commands** | Eyes-free radial dial with ≥64dp touch targets, haptic detents, offline `sherpa-onnx` VAD/ASR voice commands, and full 8-language menu/prompt localization. |
| 🔦 | **Intelligent Flashlight** | Manual and low-light-aware torch control with camera resource arbitration so flashlight and camera never conflict. |
| ✋ | **Custom Hand Gestures** | Optional on-device MediaPipe hand-landmark gesture enrolment and trigger automation. |
| 🫧 | **Floating Assistive Companion** | Optional Android overlay bubble with an honest foreground service notification for quick access outside the app. |
| 🆘 | **Emergency Assistance** | Encrypted local emergency contact storage with explicit spoken confirmation before launching the Android phone dialer. |
| 🧠 | **Local Intelligence (Beta)** | Optional, disabled-by-default on-device LLM (`LiteRT-LM`) and passive sanitized operation history. Provides chronological activity logs, offline deterministic summaries, scoped historical Q&A, and on-demand verified `.litertlm` model downloads (`Qwen3-0.6B`, `Qwen3-1.7B`, `Gemma 3n E2B`). |
| 🎨 | **WCAG AAA Accessible Themes** | Purpose-built **Dark Aubergine** and **Warm White Light** themes with ≥7:1 body contrast, zero overflow at 2.0× text scaling, and full TalkBack semantics. |

---

## 🌐 Supported Languages

Openetra localizes menus, dial prompts, errors, OCR, and spoken feedback across **8 languages**:

| Language | Code | Script / OCR | Spoken Dial & UI |
| :--- | :---: | :---: | :---: |
| **English** | `en` | Latin (ML Kit / Mirage) | ✅ |
| **Hindi (हिन्दी)** | `hi` | Devanagari (ML Kit + Tesseract) | ✅ |
| **Bengali (বাংলা)** | `bn` | Bengali (Tesseract) | ✅ |
| **Tamil (தமிழ்)** | `ta` | Tamil (Tesseract) | ✅ |
| **Telugu (తెలుగు)** | `te` | Telugu (Tesseract) | ✅ |
| **Marathi (मराठी)** | `mr` | Devanagari (ML Kit + Tesseract) | ✅ |
| **Kannada (ಕನ್ನಡ)** | `kn` | Kannada (Tesseract) | ✅ |
| **Malayalam (മലയാളം)** | `ml` | Malayalam (Tesseract) | ✅ |

---

## 🏗️ Architecture & Tech Stack

Openetra combines a modular **Flutter (BLoC)** presentation/domain layer with native **Android Kotlin** bridges for hardware, offline ML, and assistive services:

```text
lib/
├── app/                     # Dependency bootstrap, OpenetraCoordinator, WCAG AAA theme, lifecycle permission guard
├── core/
│   ├── accessibility/       # TalkBack announcer & spoken feedback utilities
│   ├── assistive/           # Action router, task orchestrator, camera/audio arbitration, PermissionCoordinator
│   ├── audio/               # SpeechController (flutter_tts), native offline ASR (sherpa-onnx), haptics
│   ├── camera/              # CameraX platform bridge
│   ├── inference/           # AIModelOrchestrator, Mirage VLM, specialist vision providers
│   ├── resource_management/ # Thermal, battery, and RAM-aware graceful degradation
│   ├── safety/              # OpenetraSafetyPolicy output filtering & audit trail
│   └── storage/             # SQLite (schema v5) for preferences, objects, scenes, gestures, and local history
└── features/
    ├── dial/                # Voice-first Assistive Radial Dial & 8-language DialLocalizer
    ├── scene_understanding/ # Scene graph, continuous scene mode, recorded scene notes
    ├── smart_reader/        # Offline Latin & Indic OCR router
    ├── object_memory/       # Personal object registration & visual search
    ├── hazard_detection/    # Hazard intelligence & uncertainty notices
    ├── currency/            # Offline INR note recognition
    ├── shopping/            # Offline barcode & product catalog lookup
    ├── emergency/           # Encrypted emergency contacts & confirmed dialer flow
    ├── flashlight/          # Intelligent torch management
    ├── gestures/            # Hand-landmark gesture automation
    ├── floating_companion/  # Optional overlay companion controls
    ├── local_intelligence/  # Optional Beta: operation history, deterministic + LiteRT-LM summaries & downloader
    └── settings/            # Appearance, language, safety, and data wipe controls

android/app/src/main/kotlin/com/openetra/app/
├── camera/                  # CameraX capture & luma telemetry
├── emergency/               # Encrypted contact storage & dialer intent
├── flashlight/              # Camera2 torch controller
├── floating/                # Foreground overlay companion service
├── gesture/                 # LiteRT hand-landmark detector
├── haptics/                 # Structured Android vibration patterns
├── local_intelligence/      # Resumable HTTPS model downloader, SHA-256 verifier & LiteRT-LM Engine
├── mirage/                  # Native JNI bridge for Mirage VLM
├── ocr/                     # ML Kit Devanagari & Tesseract4Android Indic OCR
├── resources/               # Android RAM, battery, thermal & storage probing
├── specialist/              # Visual embeddings, currency classifier & ML Kit barcode scanner
└── speech/                  # Offline sherpa-onnx VAD/ASR
```

### Key Dependencies
- **Flutter / Dart:** `flutter_bloc`, `equatable`, `sqflite`, `flutter_tts`, `permission_handler`, `crypto`, `path_provider`
- **Android Native:** `CameraX 1.3.4`, `LiteRT 1.4.2`, `LiteRT-LM 0.19.1`, `sherpa-onnx 2.0.3`, `Tesseract4Android 4.9.0`, `ML Kit Devanagari OCR 16.0.1`, `ML Kit Barcode Scanning 17.3.0`, `Kotlin Coroutines`

---

## 🔒 Privacy & Permissions

Openetra is engineered for **strict user control and transparency**:

- **Startup & Resume Permission Checks:** Every time Openetra starts or resumes from the background, `PermissionCoordinator` checks required permissions. If any are missing or revoked, Openetra presents an accessible dialog **and speaks aloud why each permission is needed** before invoking Android's system dialog (or routing to Android Settings if permanently denied).
- **Android Permissions Used:**
  - `CAMERA` — Used only when you trigger visual description, text reading, object search, currency/barcode scan, hazard cues, or an explicit gesture session.
  - `RECORD_AUDIO` — Used only when you activate voice commands for offline speech recognition.
  - `POST_NOTIFICATIONS` & `FOREGROUND_SERVICE` — Displays an honest active status notification when the optional Floating Assistive Companion is enabled.
  - `SYSTEM_ALERT_WINDOW` — Optional; used only if you enable the Floating Assistive Widget.
  - `VIBRATE` — Structured haptic feedback for eyes-free confirmation and alerts.
  - `INTERNET` & `ACCESS_NETWORK_STATE` — Used **strictly** for optional, user-initiated Local Intelligence Beta model downloads (with Wi-Fi-only toggle). Zero telemetry, zero analytics, zero cloud AI inference.
- **Independent Data Controls:** Users can independently clear operation history, delete downloaded LLM models, reset Local Intelligence, or wipe all personal data from Settings.

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK** (`>= 3.4.0`)
- **Android SDK** (`compileSdk 36`, `minSdk 26`, `targetSdk 35`, **NDK `27.0.12077973`**, **CMake `3.22.1`**)
- **JDK 17**

### Setup, Analysis & Tests

```bash
# Install Flutter dependencies
flutter pub get

# Static analysis
flutter analyze

# Run full unit & widget test suite (84 tests)
flutter test
```

### Build Android Release APK (`arm64-v8a`)

```bash
flutter build apk --release --target-platform android-arm64
```

The release APK is generated at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 📚 Documentation

Detailed architecture, accessibility, privacy, and QA documentation is maintained in [`docs/`](docs/):

- **Product & Architecture:** [`PRODUCT_VISION.md`](docs/PRODUCT_VISION.md) · [`SOFTWARE_ARCHITECTURE.md`](docs/SOFTWARE_ARCHITECTURE.md) · [`DATABASE_DESIGN.md`](docs/DATABASE_DESIGN.md) · [`PRIVACY_AND_SECURITY.md`](docs/PRIVACY_AND_SECURITY.md)
- **UX & Accessibility:** [`OPENETRA_DESIGN_SYSTEM.md`](docs/ux/OPENETRA_DESIGN_SYSTEM.md) · [`OPENETRA_DIAL_INTERACTION_SPEC.md`](docs/ux/OPENETRA_DIAL_INTERACTION_SPEC.md) · [`ACCESSIBILITY.md`](docs/ACCESSIBILITY.md)
- **AI & Vision Pipelines:** [`MIRAGE_INTEGRATION.md`](docs/MIRAGE_INTEGRATION.md) · [`OCR_ENGINE_SPECIFICATION.md`](docs/OCR_ENGINE_SPECIFICATION.md) · [`SPEECH_ENGINE_SPECIFICATION.md`](docs/SPEECH_ENGINE_SPECIFICATION.md) · [`HAZARD_DETECTION.md`](docs/HAZARD_DETECTION.md)
- **Local Intelligence (Beta):** [`LOCAL_INTELLIGENCE_ARCHITECTURE_AUDIT.md`](docs/local_intelligence/LOCAL_INTELLIGENCE_ARCHITECTURE_AUDIT.md) · [`LOCAL_INTELLIGENCE_PRIVACY_SPEC.md`](docs/local_intelligence/LOCAL_INTELLIGENCE_PRIVACY_SPEC.md) · [`LOCAL_INTELLIGENCE_MODEL_CATALOGUE.md`](docs/local_intelligence/LOCAL_INTELLIGENCE_MODEL_CATALOGUE.md) · [`LOCAL_INTELLIGENCE_BETA_RELEASE_NOTES.md`](docs/release/LOCAL_INTELLIGENCE_BETA_RELEASE_NOTES.md)
- **QA & Safety:** [`SAFETY_ENGINEERING.md`](docs/SAFETY_ENGINEERING.md) · [`OPENETRA_REGRESSION_TEST_REPORT.md`](docs/qa/OPENETRA_REGRESSION_TEST_REPORT.md) · [`LOCAL_INTELLIGENCE_REGRESSION_REPORT.md`](docs/qa/LOCAL_INTELLIGENCE_REGRESSION_REPORT.md)
