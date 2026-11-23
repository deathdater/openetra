# Openetra Product Vision

**Product:** Openetra — Offline-First, Low-Power AI Visual Independence Platform  
**Primary Users:** Completely blind and severely visually impaired individuals, with priority Indian-language and Indian-environment context.  
**Core Promise:** Transform visual information into useful, accurate, contextual, and accessible audio and haptic experiences using efficient on-device AI—requiring zero cloud dependency, zero mandatory registration, and zero continuous internet connectivity.

---

## 1. Strategic Thesis
Assistive visual applications historically suffer from two systemic failures in India and low-connectivity environments:
1. **Cloud Dependency:** High latency, mobile data cost, indoor/basement dead zones, and continuous upload of private home/document imagery.
2. **Oversized AI Pipelines:** Monolithic multi-billion-parameter VLMs that drain batteries, overheat mid-range Android phones, and generate verbose or hallucinated prose instead of concise safety-aware answers.

Openetra solves this using a **small-model ensemble with strict four-layer intelligence separation**:
- **Visual Perception (`Mirage`, ~21.6 MB 2-bit):** Fast, structured, single-pass visual perception (scene, boxes, attributes, masks, relations, Latin OCR, constrained forms).
- **Specialist Intelligence:** Compact dedicated local models only where evaluation proves a clear gain (Indic OCR, Indic ASR/TTS, Indian currency classification, optional lightweight depth & product barcodes).
- **Contextual Intelligence (`SceneUnderstandingEngine`):** Deterministic scene graph assembly, entity deduplication, temporal change tracking, and offline follow-up question answering.
- **Safety Intelligence (`HazardIntelligenceEngine` + `OpenetraSafetyPolicy`):** Independent safety evaluation separating object detection confidence from hazard relevance, image quality, and strict epistemic honesty.

---

## 2. Differentiators
1. **Mirage-Powered Visual Intelligence:** Compact ~21.6 MB multimodal perception on-device.
2. **Indian-Language Accessibility:** Priority validation across English (`en-IN`), Hindi (`hi-IN`), and Kannada (`kn-IN`), extensible via verified offline model packs for Tamil, Telugu, Malayalam, Marathi, and Bengali.
3. **Independent Hazard Intelligence:** Dedicated 5-category hazard pipeline with multi-frame IoU persistence tracking and explicit degraded-mode alerts.
4. **Adaptive Edge Inference:** Selective Mirage section requests, frame backpressure, thermal/battery governance, and six operating modes.
5. **Epistemic Honesty:** Never fabricates uncalibrated distances, never claims a road is safe to cross or a path is obstacle-free, and never replaces white canes or mobility training.
6. **True Offline Privacy:** Production Android manifest omits `INTERNET`; all user records reside locally in SQLite with user-controlled deletion.
