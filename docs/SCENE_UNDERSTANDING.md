# Scene Understanding Engine Specification

## 1. Responsibilities
`SceneUnderstandingEngine` transforms raw `VisionObservation` outputs into a structured `SceneGraph` and concise spoken `SceneDescription`.

## 2. Entity Deduplication & Normalization
- Mirage assigns shared integer entity `id` values across multiple boxes of the same object class (e.g., 11 `"chair"` detections sharing `id: 6`).
- `SceneUnderstandingEngine` aggregates identical `(entityId, normalizedName)` pairs into grouped `SceneGraphNode`s (e.g., `"3 chairs around table"` or `"multiple chairs in the center"`) so speech never repeats `"chair, chair, chair"`.

## 3. Image-Relative Positioning (No Fabricated Distances)
Normalized coordinates `0..1000` map deterministically to horizontal bands and vertical depth zones:
- **Horizontal:** `far left` (`cx < 200`), `left` (`200..380`), `center` (`380..620`), `right` (`620..800`), `far right` (`> 800`).
- **Vertical / Elevation:** `overhead` (`cy < 250` or Mirage `"ceiling"`), `middle` (`250..680`), `ground level / foreground` (`y2 > 750` or `cy > 680`).
- **Strict Rule:** Unless a calibrated `DepthProvider` supplies validated depth, distances in meters/feet are **never** emitted.

## 4. Grounded Relationships & Confidence Filtering
- Mirage `relations` (`subject -> predicate -> object`) are mapped strictly through validated `entityId` entries.
- Objects with confidence `< 0.45` are partitioned into `uncertainObservations` and narrated conservatively (`"possibly a bicycle on the right"`).
- Observations `>= 0.45` form factual scene facts.

## 5. Temporal Scene Diff & Follow-Up QA
- `ContextualQueryResolver` retains up to 5 recent `SceneGraph` frames (without retaining camera pixels).
- Compares current vs previous node names/positions to report `appeared`, `disappeared`, or `shifted` changes.
- Answers offline follow-up questions (`"what is on the left?"`, `"any text?"`, `"what changed?"`, `"repeat"`) directly from the cached fresh `SceneGraph` (`<= 8 s` old) without incurring redundant Mirage inference.
