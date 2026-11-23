# Mirage Native Integration Specification

**Model:** Mirage by Cactus Compute (`Cactus-Compute/mirage`)  
**Pinned Runtime Version:** Cactus `4.1.4`  
**Runtime Commit:** `f4ab2741203a282c6e7b89983de2b5e5b2e805a8` (Apache-2.0)  
**Model Commit:** `76c1e9e53381aca8fc3843c636216c96ff220122` (Apache-2.0)  

---

## 1. Pinned Artifact Manifest & Checksums

| Artifact | Size (Bytes) | SHA-256 |
|---|---:|---|
| `mirage.cact` | `21,611,043` | `4249a0f7515272ff76b9414bec17d7e7daf84b15b66c7fb4f17fce1e66f9f237` |
| `releases/4.1.4/manifest.json` | `8,896` | `ab948753f08e54d2b24dd04830dcb984885524ab3bd1e9da3bf207276ab62eb6` |
| `releases/4.1.4/android-arm64/cactus.h` | `1,721` | `9be7eb25b1d89180495d04a0d2c27053f282dac85add50cacc48d73302819d9d` |
| `releases/4.1.4/android-arm64/libcactus.a` | `2,898,160` | `67dbd7b856a3e9d8b0fbb68f0c59592e7572cf859238ba7f3074f74b6fa9a5da` |
| `releases/4.1.4/android-armv7/libcactus.a` | `2,307,406` | `6f7daade8587c714a2f46fdccf90535660b78d22e3c4a89518d53ea857568afa` |

---

## 2. Verified C ABI Signatures (`cactus.h`)

```c
#define CACTUS_TEXT 1
#define CACTUS_SPEECH 2
#define CACTUS_VISION 4

CACTUS_API int cactus_load(const unsigned char* cact, unsigned long long n);
CACTUS_API int cactus_models(void);
CACTUS_API const char* cactus_last_error(void);
CACTUS_API void cactus_set_threads(int threads);
CACTUS_API int cactus_describe(
    const unsigned char* rgb,
    int width,
    int height,
    const char* options,
    const char* language,
    const char* keywords,
    char* out,
    int out_capacity
);
```

### Critical Empirical ABI Rules
1. **Return Value Semantics of `cactus_describe`:**
   - Returns `< 0` on error; inspect `cactus_last_error()`.
   - Returns `>= 0` on success, representing the **generated decoder token count** (for example `282`, `336`, `4`), **not** the byte length of the JSON output!
   - `out` is always written as a NUL-terminated UTF-8 JSON C string. JNI must construct the Java/Kotlin string via `env->NewStringUTF(out_buffer.data())` (relying on NUL termination, never truncating at the return value).
2. **Thread Safety & Concurrency:**
   - Cactus maintains global engine state inside `libcactus.a`. Concurrent calls corrupt buffers or crash.
   - Openetra enforces two locks: a single `std::mutex` in `openetra_mirage_jni.cpp` and a single-thread `Executors.newSingleThreadExecutor()` in `MirageEnginePlugin.kt`.
3. **Model Verification Before Inference:**
   - After `cactus_load(bytes, size) >= 0`, assert `(cactus_models() & CACTUS_VISION) != 0`.
4. **Input Pixel Format:**
   - Packed 8-bit RGB (`width * height * 3` bytes, top-left origin, no padding bytes). EXIF rotation on files or CameraX `rotationDegrees` must be applied before passing pixels to `cactus_describe`.
5. **Valid Options JSON Keys (Verified Against Binary Strings & Probes):**
   - `sections`: subset of `["scene", "objects", "regions", "text", "relations", "events", "reasoning"]`
   - `fields`: subset of `["bbox", "score", "mask", "position", "description"]` *(Note: `"attributes"` is rejected with error `-1`)*
   - `mask_format`: `"largest"` (default polygon list), `"merged"`, `"polygons"` (nested polygons), or `"bitmap"` (`{"size":[h,w],"counts":[...]}` RLE)
   - `conf`: float `0..1`
   - `text_conf`: float `0..1`
   - `max_objects`: int `>= 1`
   - `max_text_lines`: int `>= 1`
   - `max_tokens`: int `>= 1`
   - `agnostic_nms`: bool
   - `form`: ordered dictionary of constrained extraction fields (`enum`, integer bounds, string, `x-source`)
   - `language`: e.g. `"en"` (supported languages: `en, de, fr, es, it, nl, pl`).

---

## 3. Android NDK & CMake Packaging Requirements
- **NDK:** `27.0.12077973` (`minSdk 26`, `compileSdk 35`)
- **CMake:** `3.22.1`
- **ABIs:** `arm64-v8a` (primary), `armeabi-v7a` (secondary)
- **STL:** `c++_shared` (or static LLVM `libc++` — `libcactus.a` references `std::__ndk1::*` symbols)
- **System Libraries:** `log`, `android`, `m`, `dl`
- **Page Alignment:** `-Wl,-z,max-page-size=16384` (mandatory for Android 15+ 16 KB page-size compatibility)
- **Output Shared Library:** `libopenetra_mirage.so`
- **Weight Provisioning:** `assets/models/mirage.cact` copied on first launch to `context.filesDir/models/mirage/76c1e9e5/mirage.cact`, verified via streaming SHA-256 before `cactus_load`.
