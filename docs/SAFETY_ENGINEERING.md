# Safety Engineering & Policy Guardrails

## 1. Non-Negotiable Safety Mandates (Section 9.4)
Openetra **must never**:
1. Claim a road is safe to cross (e.g., `"safe to cross"`, `"okay to cross"`).
2. Claim a path is obstacle-free (e.g., `"path is clear"`, `"way is clear"`, `"obstacle-free"`).
3. Claim all hazards have been detected (e.g., `"no hazards exist"`, `"completely safe"`).
4. State a physical distance (e.g., `"2.5 meters away"`, `"5 feet ahead"`) without a validated, calibrated depth measurement.
5. Claim an environment is safe solely because a model detected zero objects.
6. Present itself as a replacement for a white cane, guide dog, or orientation & mobility (O&M) training.
7. Claim currency counterfeit authentication.

## 2. `SafetySpeechGuard` Enforcement
Every spoken `AssistantResponse` passes synchronously through `SafetySpeechGuard.sanitize()` before reaching TTS:
- Scans outgoing prose against prohibited regular expressions (`safe to cross`, `obstacle[- ]free`, `path is clear`, `completely safe`, `\d+\s*(meters?|m|feet|ft|cm)\s*(away|ahead)` when `hasCalibratedDepth == false`, `genuine|authentic note`).
- Automatically rewrites unsafe phrasings into uncertainty-aware alternatives and logs a `SafetyEventType.policySanitizedOutput` audit entry to SQLite.

## 3. Degraded-Mode Transparency
Whenever:
- Camera frame fails `ImageQualityMetrics` (dark, blurry, glared, occluded),
- Thermal status reaches `SEVERE` or `CRITICAL` throttling,
- Inference latency violates P95 budget or `Mirage` fails to load,
`OpenetraSafetyPolicy` issues an explicit user-audible degraded warning (`SpeechPriority.warning` + `HapticPattern.degraded`) and **never silently drops hazard protection**.
