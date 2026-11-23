# Openetra Local Engineering Context

**Current Version:** `0.4.0-phase3`  
**Phase:** Phase 3 — Scene Understanding Engine & Contextual Intelligence  
**Last Updated:** 2026-11-23  
**Git Branch:** `main`  

## Implemented Components (`v0.4.0-phase3`)
- **`SceneUnderstandingEngine` (`lib/features/scene_understanding/domain/scene_understanding_engine.dart`):**
  - Deduplicates repeated Mirage `entityId` + name detections into grouped `SceneGraphNode`s (e.g., 11 chairs -> single grouped node).
  - Derives deterministic horizontal (`farLeft..farRight`) and vertical (`overhead`, `middle`, `groundLevel`) zones without inventing metric distances.
  - Filters noisy low-confidence relations (`< 0.48`) and separates uncertain items (`< 0.45`).
  - Computes temporal `SceneChange` diffs (`appeared`, `disappeared`, `shifted`) and composes concise priority-ordered speech.
- **`ContextualQueryResolver` (`lib/features/scene_understanding/domain/contextual_query_resolver.dart`):**
  - Maintains rolling 5-frame pixel-free `SceneGraph` window with freshness checks (`15 s`) and offline follow-up QA (left/right/center/overhead/ground/text/changes/object existence).
- Wired into `SceneUnderstandingBloc` in `OpenetraDependencies.bootstrap`.

## Next Milestone (`v0.5.0-phase4`)
Implement `HazardIntelligenceEngine` + `HazardTaxonomy` + `IoUTracker`, `OpenetraSafetyPolicy` + `SafetySpeechGuard`, and `SmartReader` (`ScriptDetector`, `ReadingOrderReconstructor`, `OcrRouter`).
