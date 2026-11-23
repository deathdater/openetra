# Speech Engine Specification (Offline ASR & TTS)

## 1. Speech Synthesis (Offline TTS)
- **Implementation (`SpeechController` + `DeviceResourcePlugin`):**
  - Uses Android `TextToSpeech` via `flutter_tts` combined with native `DeviceResourcePlugin.checkOfflineVoices()` inspecting `Voice.isNetworkConnectionRequired` and `TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED`.
  - Configurable speech rate (`0.35` to `1.0`), pitch, and active locale (`en-IN`, `hi-IN`, `kn-IN`, plus modular packs).
  - Supports **instant barge-in interruption** (`stopSpeaking()`) when the user taps the screen, shakes/double-taps, or invokes a priority voice/hazard interrupt.
  - Priority queue: `critical` hazard preemption cancels in-flight scene narration; `normal` descriptions queue or drop stale entries.

## 2. Offline ASR & Voice Command Routing
- **Voice Intent Router (`VoiceIntentRouter`):**
  - Deterministic, zero-cloud intent parser supporting English, Hindi (Devanagari & Hinglish transliterations), and Kannada command phrases for all workflows:
    - Describe surroundings (`describe`, `what's around`, `kya hai`, `suttamutta`)
    - Hazard scan (`hazard`, `danger`, `khatra`, `apaya`)
    - Read text (`read`, `padho`, `odu`)
    - Currency (`currency`, `note`, `paisa`, `rupee`, `hana`)
    - Find object (`find my <x>`, `where is <x>`, `dhoondo`, `huduku`)
    - Follow-ups (`left`, `right`, `repeat`, `stop`, `eco mode`, `balanced mode`)
- **Pluggable `AsrProvider` (Phase 5 `sherpa-onnx` Integration):**
  - `16 kHz`, mono, float32/PCM16 audio capture gated by Silero VAD (`~1.8 MB`) + `IndicConformer` INT8 ONNX (`~180–190 MB`).
  - Phase 1–4 ships `VoiceIntentRouter` + offline Android `SpeechRecognizer` bridge + accessible voice-command quick prompts & simulated voice input hook for 100% deterministic offline operation even without `sherpa-onnx` weights installed.

## 3. Echo & Self-Trigger Prevention
- `SpeechController` maintains an atomic `isAssistantSpeaking` lock shared with `AudioBloc`.
- While TTS is active (plus a `350 ms` acoustic tail guard), microphone ASR listening is paused/muted so assistant speech never triggers recursive commands.
