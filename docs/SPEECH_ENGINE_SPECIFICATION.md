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

---

## 4. Implemented Native Bridge & Emulator Verification (`OfflineSpeechPlugin`)
- **Channel & Native Runtime:** `OfflineSpeechPlugin` (`com.openetra.app/speech`) bundles `sherpa-onnx-static-link-onnxruntime-2.0.3.aar` (`libsherpa-onnx-jni.so`, SHA-256 `7744a3a8...`) and `assets/models/vad/silero_vad.int8.onnx` (SHA-256 `c36d490aff5ab924ca6c7aeec4d8f6bd3d22db6fa17611b9c5b17eae58ac3a20`).
- **Verified Emulator Execution (`Medium_Phone_API_35`, Android 15 ARM64):** `OfflineSpeechPlugin.provisionSileroVad` + `createVad` + `runVadOnSamples` executed on 32,000 mono `16 kHz` float samples (`1.0 s` silence + `1.0 s` modulated test signal) in `14 ms` (`speechDetected=true`, `segmentCount=1`).
- **Pluggable External ASR Packs:** `loadAsrPack` verifies SHA-256 digests before constructing `com.k2fsa.sherpa.onnx.OfflineRecognizer` (`OfflineNemoEncDecCtcModelConfig`). When no Conformer pack is installed locally, `status` reports `osOnDeviceSpeechAvailable` via `SpeechRecognizer.isOnDeviceRecognitionAvailable` (API 31+) and surfaces `OfflineVoiceUnavailableFailure` cleanly rather than making cloud calls.
- **Echo-Safe UI Trigger:** `HomeScreen` offline microphone control rejects capture with `OpenetraLocalizer.micGatedNotice` when `AudioBloc` reports `isSpeaking == true`.
