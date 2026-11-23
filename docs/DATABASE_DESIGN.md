# Offline SQLite Database Design

**Engine:** Android SQLite via `sqflite` (`sqflite_common_ffi` for host unit tests)  
**Database File:** `openetra.db` (Schema Version `1`, stored in app-private storage)  
**Privacy Rule:** Zero automatic storage of raw camera images.

---

## 1. Schema Tables (10 Required Entities)

1. **`user_preferences`**: Single-row key/value store for active language (`en-IN`), operating mode (`balanced`), high-contrast/verbose flags, onboarding completion, safety disclaimer acceptance.
2. **`voice_config`**: `locale` (PK), `speech_rate`, `pitch`, `preferred_voice_name`, `is_offline_verified`, `barge_in_enabled`.
3. **`personal_objects`**: `id` (PK), `name`, `category`, `color_hint`, `description`, `created_at_ms`, `updated_at_ms`.
4. **`object_embeddings`**: `id` (PK), `object_id` (FK -> `personal_objects.id` ON DELETE CASCADE), `model_id`, `embedding_blob` (`BLOB`), `dimension`, `created_at_ms`.
5. **`last_seen_records`**: `id` (PK), `object_id` (FK -> `personal_objects.id` ON DELETE CASCADE), `scene_setting`, `relative_position`, `confidence`, `seen_at_ms`.
6. **`scanned_documents`**: `id` (PK), `title`, `detected_script`, `extracted_text`, `confidence`, `language`, `created_at_ms`. *(Created only on explicit user save; never retains camera photo unless user exports.)*
7. **`conversation_history`**: `id` (PK), `role` (`user`/`assistant`), `intent`, `utterance`, `language`, `created_at_ms`.
8. **`model_registry`**: `model_id` (PK), `version`, `task`, `runtime`, `file_path`, `expected_sha256`, `actual_sha256`, `verified_at_ms`, `status`, `size_bytes`, `licence`.
9. **`safety_events`**: `id` (PK), `event_type`, `severity`, `message`, `degraded_reason`, `hazard_category`, `created_at_ms`.
10. **`benchmark_metadata`**: `id` (PK), `model_id`, `device_tier`, `input_width`, `input_height`, `cold_load_ms`, `inference_ms`, `thermal_state`, `recorded_at_ms`.

---

## 2. User Data Deletion
`OpenetraDatabase.deleteAllUserData()` wipes `personal_objects`, `object_embeddings`, `last_seen_records`, `scanned_documents`, `conversation_history`, and `safety_events` inside an atomic transaction while preserving verified read-only `model_registry` metadata unless factory reset is chosen.
