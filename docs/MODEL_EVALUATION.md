# Reproducible AI Model Evaluation Framework

## 1. Scene Understanding Evaluation
- **Metrics:** Object precision/recall, spatial relationship precision, hallucination rate (e.g., `"rug on dining table"`), duplicate entity phrasing rate, median/P95 end-to-end speech latency.
- **Reference Fixtures:** Bundled deterministic COCO fixtures (`000000231049.jpg`, `000000000139.jpg`) plus labelled Indian indoor/street evaluation sets.

## 2. Hazard Detection Evaluation
- **Metrics:** Per-category precision & recall (Ground-level, Vertical, Elevation, Traffic, Indoor), **Dangerous False-Negative Rate** (primary P0 metric), false-alert rate per minute, IoU temporal persistence stability, low-light degradation behavior.
- **Indian Environment Benchmark Requirement:** Labelled scenes covering unpaved footpaths, open storm drains, hanging low cables, auto-rickshaws, two-wheelers, unmarked speed breakers, crowded markets, railway platforms, and indoor stairwells.

## 3. Indic OCR Evaluation
- **Metrics:** Character Error Rate (CER), Word Error Rate (WER), script classification accuracy, reading-order edit distance.
- **Test Corpus:** Printed Hindi, Kannada, Tamil, Telugu, English, bilingual signage, medicine blister packs, packaged food labels, utility bills.

## 4. Speech Recognition & TTS Evaluation
- **ASR Metrics:** Command intent accuracy, WER across native speech, English (`en-IN`), Hinglish/Kanglish code-switching, background traffic noise (60–75 dB SNR), elderly and slow speech rates.
- **TTS Metrics:** Offline availability ratio, speech onset latency (<1s target), pronunciation intelligibility checked by native speakers.

## 5. Performance & Power Evaluation
- **Metrics:** Cold load ms, warm describe ms, P50/P95/P99 latency, RSS peak RAM, mAh battery drain over 15-minute Hazard Awareness session, thermal status transitions (`NONE -> LIGHT -> MODERATE -> SEVERE`).
- **Tiers:** Entry-level (4 GB RAM Cortex-A55), mid-range (6–8 GB Snapdragon 6/7), flagship (8–12 GB), plus documented ARM64 emulator verification results kept strictly distinct from physical hardware numbers.
