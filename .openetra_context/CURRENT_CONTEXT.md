# Openetra Local Engineering Context

**Current Version:** `0.1.0-phase0`  
**Phase:** Phase 0 — Repository Reconnaissance, Runtime Verification, Model Research & Architecture Specification  
**Last Updated:** 2026-11-23  
**Git Branch:** `main`  

## Active Toolchain & Verified Environment
- **Workspace:** `/Volumes/Dater 5TB/1.0 Python Projects/Openetra` (greenfield, initialized with Git on `main`)
- **Host OS:** macOS 15.1 (Apple Silicon `arm64`)
- **Flutter / Dart:** `3.22.3` / `3.4.4` (`/Users/deathdater/development/flutter/bin/flutter`)
- **JDK:** OpenJDK `21.0.10` (`/Applications/Android Studio.app/Contents/jbr/Contents/Home`)
- **Android SDK:** `/Users/deathdater/Library/Android/sdk` (`android-31`, `android-34`, `android-35`, `android-36`; build-tools up to `37.0.0`; emulator `36.5.11` with arm64-v8a AVDs `Medium_Phone_API_35`, `Pixel_Fold_API_35`)
- **Action Needed in Phase 2:** Install `ndk;27.0.12077973` and `cmake;3.22.1` via `sdkmanager`, and use Gradle `8.7` + AGP `8.5.2` + Kotlin `1.9.24` (required for OpenJDK 21 compatibility).

## Verified Model & Runtime Pins
- **Cactus Runtime:** `4.1.4` (`Cactus-Compute/cactus` commit `f4ab2741203a282c6e7b89983de2b5e5b2e805a8`, Apache-2.0)
  - `manifest.json` SHA-256: `ab948753f08e54d2b24dd04830dcb984885524ab3bd1e9da3bf207276ab62eb6`
  - `android-arm64/libcactus.a` (2,898,160 B) SHA-256: `67dbd7b856a3e9d8b0fbb68f0c59592e7572cf859238ba7f3074f74b6fa9a5da`
  - `android-armv7/libcactus.a` (2,307,406 B) SHA-256: `6f7daade8587c714a2f46fdccf90535660b78d22e3c4a89518d53ea857568afa`
  - `cactus.h` (1,721 B) SHA-256: `9be7eb25b1d89180495d04a0d2c27053f282dac85add50cacc48d73302819d9d`
- **Mirage Vision Model:** `Cactus-Compute/mirage` commit `76c1e9e53381aca8fc3843c636216c96ff220122`, Apache-2.0
  - `mirage.cact` (21,611,043 B) SHA-256: `4249a0f7515272ff76b9414bec17d7e7daf84b15b66c7fb4f17fce1e66f9f237`

## Key Empirical Findings Carried Forward
1. `cactus_describe()` returns the **decoder token count** (not byte count) when `>= 0` and writes a NUL-terminated JSON string into `out`. Always read `out` as a C string.
2. Valid Mirage `sections`: `scene`, `objects`, `regions`, `text`, `relations`, `events`, `reasoning`.
3. Valid Mirage `fields`: `bbox`, `score`, `mask`, `position`, `description` (passing `attributes` returns `-1`).
4. `objects[].id` is an entity group ID shared across multiple boxes of the same entity.
5. PaddleOCR `ka_dict.txt` maps to Kannada (`ka`), not Georgian, but only `ka_PP-OCRv3_mobile_rec` exists (not PP-OCRv5); `tesseract-ocr/tessdata_fast` (`kan.traineddata`, 3.44 MB, Apache-2.0) is verified offline across all 8 priority/target Indic languages.
6. Meta MMS VITS TTS weights carry `CC-BY-NC 4.0` and are excluded from production shipping builds.

## Next Milestone (`v0.2.0-phase1`)
Scaffold the Flutter Android application with Clean Architecture + BLoC, all 18 domain data contracts, SQLite schema, SHA-256 model integrity verification, AI orchestration & resource management core, and accessible voice-first UI shell.
