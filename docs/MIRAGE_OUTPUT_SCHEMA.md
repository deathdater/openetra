# Mirage Output JSON Schema Specification

This specification is derived directly from empirical C ABI runs of `mirage.cact` (`76c1e9e53381aca8fc3843c636216c96ff220122`) against Cactus runtime `4.1.4` on real COCO images (`000000231049`, `000000000139`, `000000000785`, `000000001000`, `000000002153`).

---

## 1. Top-Level Structure (Describe Mode)

```json
{
  "scene": {
    "setting": "suburban street",
    "background": "trees and buildings",
    "surface": "pavement",
    "lighting": "daylight",
    "weather": "clear",
    "time_of_day": "day",
    "sky": "blue"
  },
  "objects": [
    {
      "id": 4,
      "name": "stop sign",
      "bbox": [377, 238, 643, 436],
      "score": 0.640,
      "mask": [449, 244, "..."],
      "position": "center",
      "description": {
        "color": "red",
        "shape": "octagonal",
        "state": "standing"
      }
    }
  ],
  "regions": [],
  "text": [
    {
      "string": "ARRET",
      "bbox": [364, 297, 657, 379],
      "score": 0.871
    }
  ],
  "relations": [
    {"subject": 4, "predicate": "attached_to", "object": 6}
  ],
  "events": [
    {"actor": 2, "action": "playing"}
  ],
  "reasoning": "lang: en | ..."
}
```

---

## 2. Field Contracts & Edge Cases Observed

1. **Coordinate Scale (`bbox` & polygon `mask`):**
   - `[x1, y1, x2, y2]` normalized on integer `0..1000` relative to image width (`x`) and height (`y`).
2. **Entity Grouping (`objects[].id`):**
   - Integer `id` identifies an entity type/group within the frame rather than a unique per-box ID. Example observed in `000000000139.jpg`: 11 distinct `"chair"` boxes all share `"id": 6`.
   - `relations[].subject`, `relations[].object`, and `events[].actor` reference this entity `id`.
3. **Optional/Omitted Sections:**
   - Even when `"scene"` is requested, Mirage can return `scene` as `null` or omit `"scene"` (observed on `000000000785.jpg`). Parsers must treat all sections defensively as nullable/optional.
4. **Mask Formats:**
   - `"largest"` (default): flat integer list `[x1, y1, x2, y2, ...]` (0..1000 coords).
   - `"polygons"`: list of polygon integer lists `[[x1, y1, ...], ...]`.
   - `"bitmap"`: object `{"size": [height, width], "counts": [...]}` (RLE counts at image resolution).
5. **OCR (`text`):**
   - Returns Latin-script text lines with `"string"`, `"bbox"`, `"score"`. Characters are restricted to Mirage's 306-character Latin/Extended-A alphabet (`ARRET` instead of `ARRÊT` observed on `231049`).
6. **Constrained Forms (`form` Mode):**
   - Example verified response:
     ```json
     {"form":{"sign":{"value":"stop","probabilities":{"stop":0.7713,"yield":0.0804,"speed limit":0.0482,"-":0.1001}}}}
     ```
   - Notice `"-"` represents abstention / out-of-set probability mass.
7. **Known Hallucination / Noise Modes:**
   - `000000000139.jpg` generated relation `{"subject": 8, "predicate": "on", "object": 7}` ("rug on dining table").
   - `reasoning` traces can contain grammatical errors or unsupported inferences (`"stop sign is in front of the sign"`). Openetra never reads raw `reasoning` directly to blind users.
