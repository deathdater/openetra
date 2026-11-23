# Openetra Local Intelligence (Beta) — Data Model & SQLite v5 Migration

**Database:** `OpenetraDatabase` (`lib/core/storage/openetra_database.dart`, upgraded `schemaVersion = 4 -> 5`)

## 1. New Tables (Additive Migration `oldVersion < 5`)
- `operation_history_events`:
  - `event_id TEXT PRIMARY KEY`
  - `schema_version INTEGER NOT NULL` (currently `1`)
  - `operation_type TEXT NOT NULL` (`sceneDescription`, `textReading`, `objectSearch`, `hazardScan`, `currencyCheck`, `sceneRecording`, `historicalSummary`)
  - `status TEXT NOT NULL` (`completed`, `notFound`, `cancelled`, `failed`)
  - `started_at_ms INTEGER NOT NULL`, `completed_at_ms INTEGER NOT NULL`, `duration_ms INTEGER NOT NULL`
  - `sanitized_summary TEXT NOT NULL`, `metadata_json TEXT NOT NULL`
  - `model_id TEXT`, `language TEXT NOT NULL`, `initiator TEXT NOT NULL`, `error_category TEXT`, `expires_at_ms INTEGER`
  - Indexed on `completed_at_ms DESC` (`idx_op_history_completed`).
- `local_intelligence_models`:
  - `model_id TEXT PRIMARY KEY`, `version TEXT NOT NULL`, `local_path TEXT NOT NULL`, `sha256 TEXT NOT NULL`, `size_bytes INTEGER NOT NULL`, `status TEXT NOT NULL`, `verified_at_ms INTEGER NOT NULL`.

## 2. Configuration Keys (Reusing `assistive_preferences`)
`li_enabled`, `li_history_enabled`, `li_summaries_enabled`, `li_wifi_only`, `li_retention_days`, `li_active_model_id`, `li_privacy_accepted`.
