# Openetra Local Intelligence (Beta) — Privacy, Retention & Safety Specification

## 1. Strict Local-Only & Zero-Telemetry Boundary
- **Disabled by Default:** `enabled = false`, `historyEnabled = false`, `summariesEnabled = false`.
- **Zero Cloud Inference / Zero Analytics:** All history queries, deterministic summaries, and optional LiteRT-LM inference run 100% locally in app-private storage. `AndroidManifest.xml` retains zero `INTERNET` permission.
- **What IS Stored (Only When History Is Explicitly Enabled):**
  - Timestamp, duration, operation type enum, status enum, language code, optional model ID, and a short sanitized summary (`<= 220` chars) processed by `OperationHistorySanitizer`.
- **What Is NEVER Stored:**
  - Raw camera images or videos, raw audio recordings, full OCR document contents (only script & word count metadata), email addresses (`[redacted email]`), phone/card/OTP digit sequences (`[redacted number]`), passwords/PINs (`[redacted]`), or unrestricted conversation logs.

## 2. Independent Data Lifecycle & Retention
- **Retention Options:** `7 days`, `30 days` (default), `90 days`, or `Keep until manually deleted`. Expired records are automatically pruned on load and on new event insertion.
- **Independent Controls:**
  - Disabling Local Intelligence unloads any active LLM immediately and stops inference while preserving stored history per retention policy.
  - **Delete Model Only** removes `.litertlm` files & model table rows while preserving operation history.
  - **Clear Operation History** wipes `operation_history_events` while preserving downloaded models.
  - **Reset Local Intelligence** (explicit confirmation required) disables the feature, deletes models, and clears history without affecting core Openetra settings or belongings.
