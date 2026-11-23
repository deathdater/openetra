# Openetra Product Requirements & Incremental Backlog

## 1. Non-Negotiable Principles

| Priority | Principle | Verification Gate |
|---|---|---|
| P0 | **User safety** | `SafetySpeechGuard` blocks prohibited safety/distance/counterfeit claims; degraded quality/thermal limits always announced. |
| P0 | **Accuracy** | Confidence thresholds separate uncertain guesses ("possibly ...") from high-confidence observations. |
| P0 | **Accessibility** | Full TalkBack semantics, >=64dp targets, WCAG AAA dark contrast, barge-in audio, haptic confirmations, zero visual-only critical alerts. |
| P0 | **Offline operation** | No `INTERNET` permission in production Android manifest; airplane-mode operation 100% functional after asset provisioning. |
| P0 | **Privacy** | Zero telemetry, zero automatic image saving, SHA-256 verified local models, user-controlled SQLite wipe. |
| P1 | **Low power** | Selective Mirage queries, `STRATEGY_KEEP_ONLY_LATEST` backpressure, 6 operating modes, thermal & battery throttling. |
| P1 | **Indian localisation** | `en-IN`, `hi-IN`, `kn-IN` priority workflows + modular pack architecture for `ta-IN`, `te-IN`, `ml-IN`, `mr-IN`, `bn-IN`. |

---

## 2. Required User Workflows & Acceptance Criteria

### Workflow A — Describe Surroundings
- **Trigger:** Voice `"Describe my surroundings"` / `"What's around me"` or primary button **Describe Surroundings**.
- **Flow:** Camera activation -> Image quality check -> Mirage selective perception (`scene`, `objects`, `relations`, `events`, `text`) -> `SceneUnderstandingEngine` scene graph -> `HazardIntelligenceEngine` hazard check -> `OpenetraSafetyPolicy` guard -> Concise prioritized TTS + haptic cue.
- **Acceptance Criteria:** Deduplicates repeated entities (`id`), expresses image-relative positions (`left/center/right`, `foreground/middle/background`), answers follow-up queries ("what's on my left?"), never invents metric distances.

### Workflow B — Hazard Awareness
- **Trigger:** Voice `"Look for hazards"` / `"Hazard mode"` or button **Hazard Awareness**.
- **Flow:** Continuous throttled camera capture -> Image quality gate -> Mirage hazard-relevant perception -> Candidate extraction across 5 categories -> `IoUTracker` temporal persistence -> 5-component confidence breakdown -> `OpenetraSafetyPolicy` prioritization -> Urgent TTS preemption + directional/severity haptic pulse.
- **Acceptance Criteria:** Explicit degraded announcement on dark/blurred/overexposed frames or thermal throttling; never outputs `"safe to cross"` or `"path is clear"`.

### Workflow C — Read Indian-Language Text
- **Trigger:** Voice `"Read this"` or button **Read Text**.
- **Flow:** Capture -> Quality check -> Script detection (Latin vs Devanagari/Kannada/Tamil/Telugu/Malayalam/Bengali) -> `OcrRouter` (Latin -> Mirage OCR; Indic -> pluggable Indic OCR pack) -> `ReadingOrderReconstructor` -> Confidence evaluation -> Offline TTS in matching locale.
- **Acceptance Criteria:** Properly sorts multi-line Latin blocks via Mirage OCR; accurately identifies Indic script codepoints and discloses cleanly when an optional offline Indic OCR or TTS pack is not installed yet.

### Workflow D — Find Personal Belongings
- **Trigger:** Voice `"Find my <object>"` or **Object Memory** workflow.
- **Flow:** Load SQLite `PersonalObjectProfile` -> Capture scene -> Mirage open-vocabulary matching + optional `EmbeddingProvider` cosine similarity -> Image-relative position report; if multiple candidates exist, prompt user for disambiguation.
- **Acceptance Criteria:** Supports adding/deleting personal objects locally in SQLite and updating `last_seen_records`.

### Workflow E — Indian Currency Recognition
- **Trigger:** Voice `"Identify this note"` or **Identify Currency** button.
- **Flow:** Capture note -> Quality gate -> Pluggable `CurrencyClassifierProvider` (`₹10, ₹20, ₹50, ₹100, ₹200, ₹500`) + Mirage numeral OCR cross-check -> Uncertainty reporting + explicit non-counterfeit disclaimer.
- **Acceptance Criteria:** Never relies on color alone; never claims a note is genuine or counterfeit.

---

## 3. Phased Incremental Backlog

| Phase | Milestone | Scope & Acceptance Criteria | Target Status |
|---|---|---|---|
| **0** | `v0.1.0-phase0` | Repo reconnaissance, Cactus `4.1.4` + Mirage C ABI empirical probe, model evaluation & architecture docs. | Done |
| **1** | `v0.2.0-phase1` | Flutter Clean Architecture scaffold, Gradle 8.7/AGP 8.5.2, 18 domain entities, SQLite schema, AI orchestrator, resource manager, 11 BLoCs, accessible voice-first UI shell. | Next |
| **2** | `v0.3.0-phase2` | NDK 27 + CMake, `libopenetra_mirage.so` linking `libcactus.a`, CameraX, DeviceResource/TTS-voice check, Haptics, `MirageInferenceProvider` + SHA-256 verification. | Planned |
| **3** | `v0.4.0-phase3` | `SceneUnderstandingEngine`, `ContextualQueryResolver`, Workflow A E2E. | Planned |
| **4** | `v0.5.0-phase4` | `HazardIntelligenceEngine`, `IoUTracker`, `OpenetraSafetyPolicy`, `SafetySpeechGuard`, Workflows B–E. | Planned |
| **5** | `v0.6.0-mvp-vertical-slice` (tests + emulator) & Future Indic Pack | Unit/BLoC/widget/SQLite/safety test suite + real ARM64 emulator verification; subsequent Phase 5 rollout of Indic PP-OCRv5/Tesseract + `sherpa-onnx` IndicConformer packs. | Planned |
| **6–8** | Post-MVP | Trained Indian currency TFLite classifier, Depth Anything V2 Small pack, field benchmarks on low/mid/flagship phones, blind-user usability trials. | Planned |
