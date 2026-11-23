# Privacy & Security Architecture

## 1. Local-Only Guarantees
- **Zero Cloud AI:** Mirage inference, scene understanding, hazard intelligence, safety speech gating, and SQLite memory run 100% on-device.
- **OS-Level Network Exclusion:** Production `AndroidManifest.xml` omits `android.permission.INTERNET`, ensuring release builds cannot open outbound network sockets.
- **Zero Compulsory Registration:** Immediate launch without accounts, phone numbers, or cloud IDs.
- **Zero Automatic Photo Retention:** Camera frames reside only in short-lived memory buffers for inference and are discarded immediately afterwards unless a user explicitly invokes save on scanned text.

## 2. Model Integrity & Supply-Chain Security
- Every native library and model binary is pinned by exact Git commit and SHA-256 checksum.
- `ModelChecksumVerifier` verifies `mirage.cact` SHA-256 (`4249a0f7515272ff76b9414bec17d7e7daf84b15b66c7fb4f17fce1e66f9f237`) inside app-private storage (`context.filesDir/models/...`) before `MirageEnginePlugin` executes `cactus_load`.
- Checksum mismatches abort loading immediately with `ModelIntegrityFailure` and log a `SafetyEvent`.
- **No Unverified Execution:** Model downloads or imports with unknown checksums are rejected.

## 3. User-Controlled Data Deletion
Users can delete individual personal objects, clear scanned documents, wipe conversation history, or run one-action **Delete All Local Data** in Settings (`OpenetraDatabase.deleteAllUserData()`).
