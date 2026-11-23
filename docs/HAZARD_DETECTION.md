# Independent Hazard Intelligence Engine Specification

## 1. Design Separation
Hazard evaluation is completely decoupled from general conversational generation. Raw detector confidence (`score`) is **never** equated directly to safety probability.

## 2. Covered Hazard Taxonomy (5 Core Categories + Critical Cues)
1. **Ground-Level:** Pothole, open drain / manhole, uneven pavement, loose floor object, cable / cord on floor, broken pavement, construction debris, slippery/wet floor.
2. **Vertical / Head-Height:** Low-hanging branch, protruding object, open cabinet door, overhead structure / low beam, hanging wire / cable.
3. **Elevation Changes:** Stairs / steps, drop-off, curb, ramp, raised surface / speed bump, railway/metro platform edge.
4. **Traffic:** Car, bus, truck, auto-rickshaw, motorcycle / scooter, bicycle, moving vehicle, pedestrian crowding, road intersection / crossing.
5. **Indoor Obstructions:** Furniture obstruction in path, open drawer, glass barrier / door, object on staircase, spilled liquid.
6. **Additional High-Risk Cues:** Fire, smoke, broken glass, warning/danger signs.

## 3. Multi-Stage Pipeline
1. **Image Quality Gate (`ImageQualityMetrics`):** Evaluates native C++ luma mean (`< 28` too dark), Laplacian variance (`< 35` motion blur), and overexposure ratio (`> 0.45` glare). If degraded, emits an explicit `Degraded` warning rather than pretending the scene is clear.
2. **Candidate Extraction:** Matches Mirage objects, descriptions, regions, and text (`DANGER`, `CAUTION`, `WET FLOOR`, `EXIT`, `WORK IN PROGRESS`) against `HazardTaxonomy`.
3. **IoU Temporal Tracker (`IoUTracker`):** Tracks candidates across frames using bounding-box Intersection-over-Union (`IoU >= 0.30`), tracking consecutive hit counts, persistence score, and relative box expansion (looming indicator).
4. **Spatial Path Relevance:** Evaluates center-corridor overlap (`x in 220..780`) and ground/vertical zones relevant to walking safety.
5. **Five-Factor Confidence Breakdown (`HazardConfidenceBreakdown`):**
   - `detectionConfidence` (from model)
   - `hazardClassificationConfidence` (rule/specialist match strength)
   - `spatialConfidence` (center/path alignment)
   - `distanceConfidence` (`null` unless calibrated `DepthProvider` is active)
   - `temporalPersistenceScore` (across consecutive tracked frames)
6. **Severity & Cooldown:** Assigns `info`, `caution`, `warning`, or `critical`, suppressing duplicate identical alerts within a configurable cooldown window unless severity escalates.
