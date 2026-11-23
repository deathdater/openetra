# Privacy & Security Architecture

## 1. Local-Only Guarantees
- **Zero Cloud AI:** Mirage inference, scene understanding, hazard intelligence, safety speech gating, and SQLite memory run 100% on-device.
- **OS-Level Network Exclusion:** Both `android/app/src/main/AndroidManifest.xml` and `android/app/src/release/AndroidManifest.xml` (which removes transitive `INTERNET` and `ACCESS_NETWORK_STATE` permissions via `tools:node="remove"`) guarantee release APKs hold zero network permissions. Verified on `app-release.apk` (`142,993,414 B`) with `aapt2 dump permissions`: declares `CAMERA`, `RECORD_AUDIO`, `VIBRATE`, and `com.openetra.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` only.
- **Zero Compulsory Registration:** Immediate launch without accounts, phone numbers, or cloud IDs.
- **Zero Automatic Photo Retention:** Camera frames reside only in short-lived memory buffers for inference and are discarded immediately afterwards unless a user explicitly invokes save on scanned text.

## 2. Model Integrity & Supply-Chain Security
- Every native library and model binary is pinned by exact Git commit and SHA-256 checksum.
- `ModelChecksumVerifier` verifies `mirage.cact` SHA-256 (`4249a0f7515272ff76b9414bec17d7e7daf84b15b66c7fb4f17fce1e66f9f237`), all 7 bundled Tesseract `tessdata_fast` files (`hin`, `mar`, `kan`, `tam`, `tel`, `mal`, `ben`), and `silero_vad.int8.onnx` (`c36d490a...`) inside app-private storage before native initialization; optional external packs (banknote `.tflite`, depth `.tflite`, `IndicConformer`) enforce SHA-256 checks inside `loadCurrencyModel`, `loadDepthModel`, and `loadAsrPack`.
- Checksum mismatches abort loading immediately with `ModelIntegrityFailure` / `SecurityException` and log a `SafetyEvent`.
- **No Unverified Execution:** Model downloads or imports with unknown checksums are rejected.

## 3. User-Controlled Data Deletion
Users can delete individual personal objects, clear scanned documents, wipe conversation history, or run one-action **Delete All Personal Data** in Settings (`OpenetraDatabase.deleteAllUserData()`), guarded by an accessible two-step confirmation dialog (`Cancel` / `Permanently Delete`) to prevent accidental TalkBack double-tap wipes while keeping `builtin_sample` local product entries offline.
