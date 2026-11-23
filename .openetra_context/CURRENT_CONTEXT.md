# Openetra Local Engineering Context

**Current Version:** `0.8.0-phase6-specialist-and-shopping`  
**Phase:** Phase 6 — SQLite v2 Product Catalog, Specialist Vision Plugin, Object Embeddings & Currency Fusion  
**Last Updated:** 2026-11-23  
**Git Branch:** `main`  

## Verified Phase 6 Changes (`flutter analyze` clean, 24/24 baseline tests passing)
- **SQLite Schema v2 (`lib/core/storage/openetra_database.dart`):** Upgraded schema from v1 to v2 with `local_products` table, `onUpgrade` migration, 5 seeded Indian EAN-890 staples (`source = 'builtin_sample'`), `getObjectEmbeddings`, `lookupLocalProduct`, `upsertLocalProduct`, and `listLocalProducts`; `deleteAllUserData()` wipes user-added entries while retaining builtin sample items.
- **Native Specialist Vision (`SpecialistVisionPlugin.kt` + `NativeSpecialistProviders`):** Registered `com.openetra.app/specialist` in `MainActivity.kt` providing ML Kit `17.3.0` offline barcode scanning, deterministic 96-dimensional L2-normalized HSV + spatial grid + luminance-gradient visual crop descriptors (`computeCropDescriptor96`), and LiteRT `2.4.0` (`org.tensorflow.lite.Interpreter`) banknote classifier slot.
- **Feature & Domain Integration:**
  - `ObjectMemoryBloc` stores visual crop embeddings on registration and disambiguates multi-match finds via cosine similarity.
  - `CurrencyRecognitionService` defines `mirageCurrencyFormSchema` and fuses Mirage structured `form` output, OCR denomination numerals, and optional LiteRT classifier probabilities with non-counterfeit disclaimers.
  - `ShoppingAssistantService` + `SqliteProductCatalogLookup` + accessible `ShoppingScreen` wired into `OpenetraCoordinator` (`runScanProduct`) and `HomeScreen`.
- **Remaining Pending:** Currency banknote dataset training (`.tflite` weights), expanded Phase 5–6 host unit tests, `IndicAndSpecialistInstrumentedTest.kt` on `Medium_Phone_API_35`, and final benchmark sync (`v0.9.0-phase5-7-verified`).
