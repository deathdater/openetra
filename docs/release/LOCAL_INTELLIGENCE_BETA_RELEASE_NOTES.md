# Openetra Local Intelligence (Beta) — Release Notes (`v2.4.0-local-intelligence-beta`)

**Date:** 2026-11-23

## What's New
- **Optional Local Activity History (Disabled by Default):** Passive, non-blocking, privacy-sanitized logging of completed/failed Openetra operations in SQLite v5 (`operation_history_events`) with `7/30/90/Manual` retention and automatic expiry pruning.
- **Accessible Activity History & Deterministic Summaries:** Browse chronological date-grouped history, filter by category/status, hear explicit historical records (*"earlier recorded activity, not a current camera view"*), generate **Brief**, **Detailed**, and **Activity-focused** summaries, and ask session-scoped follow-up questions — working 100% offline with or without an LLM.
- **Verified Optional LiteRT-LM Model Management:** Native Android hardware compatibility probe (`LocalIntelligencePlugin.kt`), manifest catalogue (`Qwen3-0.6B`, `Qwen3-1.7B`, `Gemma 3n E2B-IT`), SHA-256 verification, smoke-test gate, strict output validation, and independent **Delete Model**, **Clear History**, and **Reset Local Intelligence** controls.
- **Zero Regressions:** `flutter analyze` reports `0` issues, all **81/81** tests pass, `0` new Dart dependencies were added, and `AndroidManifest.xml` preserves zero `INTERNET` permission.
