#include <jni.h>
#include <android/log.h>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <fstream>
#include <mutex>
#include <string>
#include <vector>

#include "cactus.h"

namespace {

constexpr const char* kLogTag = "OpenetraMirageJNI";
constexpr size_t kOutputBufferBytes = 16 * 1024 * 1024;

std::mutex g_cactus_mutex;
std::vector<char> g_output_buffer;
std::vector<unsigned char> g_rgb_scratch;

void ThrowJavaException(JNIEnv* env, const char* class_name, const char* message) {
  jclass cls = env->FindClass(class_name);
  if (cls != nullptr) {
    env->ThrowNew(cls, message != nullptr ? message : "Unknown native error");
    env->DeleteLocalRef(cls);
  }
}

void EnsureOutputBuffer() {
  if (g_output_buffer.size() != kOutputBufferBytes) {
    g_output_buffer.assign(kOutputBufferBytes, '\0');
  }
}

}  // namespace

extern "C" {

JNIEXPORT void JNICALL
Java_com_openetra_app_mirage_MirageNativeBridge_nativeSetThreads(
    JNIEnv*,
    jclass,
    jint threads) {
  std::lock_guard<std::mutex> lock(g_cactus_mutex);
  cactus_set_threads(static_cast<int>(threads));
}

JNIEXPORT jboolean JNICALL
Java_com_openetra_app_mirage_MirageNativeBridge_nativeIsVisionLoaded(
    JNIEnv*,
    jclass) {
  std::lock_guard<std::mutex> lock(g_cactus_mutex);
  return (cactus_models() & CACTUS_VISION) != 0 ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jint JNICALL
Java_com_openetra_app_mirage_MirageNativeBridge_nativeLoadModelFile(
    JNIEnv* env,
    jclass,
    jstring path_jstr) {
  if (path_jstr == nullptr) {
    ThrowJavaException(env, "java/lang/IllegalArgumentException", "Model path is null");
    return -1;
  }

  const char* path_cstr = env->GetStringUTFChars(path_jstr, nullptr);
  if (path_cstr == nullptr) {
    return -1;
  }
  std::string path(path_cstr);
  env->ReleaseStringUTFChars(path_jstr, path_cstr);

  std::ifstream file(path, std::ios::binary | std::ios::ate);
  if (!file.is_open()) {
    std::string msg = "Unable to open model file: " + path;
    ThrowJavaException(env, "java/lang/IllegalStateException", msg.c_str());
    return -1;
  }

  std::streamsize file_size = file.tellg();
  if (file_size <= 0) {
    ThrowJavaException(env, "java/lang/IllegalStateException", "Model file is empty");
    return -1;
  }
  file.seekg(0, std::ios::beg);

  std::vector<unsigned char> weights(static_cast<size_t>(file_size));
  if (!file.read(reinterpret_cast<char*>(weights.data()), file_size)) {
    ThrowJavaException(env, "java/lang/IllegalStateException", "Failed reading model bytes");
    return -1;
  }

  std::lock_guard<std::mutex> lock(g_cactus_mutex);
  EnsureOutputBuffer();

  int rc = cactus_load(weights.data(), static_cast<unsigned long long>(weights.size()));
  if (rc < 0) {
    const char* err = cactus_last_error();
    __android_log_print(ANDROID_LOG_ERROR, kLogTag, "cactus_load failed: %s", err ? err : "unknown");
    ThrowJavaException(env, "java/lang/IllegalStateException", err ? err : "cactus_load failed");
    return -1;
  }

  int mask = cactus_models();
  if ((mask & CACTUS_VISION) == 0) {
    ThrowJavaException(env, "java/lang/IllegalStateException",
                       "Loaded archive does not advertise CACTUS_VISION capability");
    return -1;
  }
  __android_log_print(ANDROID_LOG_INFO, kLogTag,
                      "Loaded Mirage (%zu bytes), models mask=%d", weights.size(), mask);
  return static_cast<jint>(mask);
}

JNIEXPORT jbyteArray JNICALL
Java_com_openetra_app_mirage_MirageNativeBridge_nativeDescribeRgb(
    JNIEnv* env,
    jclass,
    jbyteArray rgb_array,
    jint width,
    jint height,
    jstring options_json_jstr,
    jstring language_jstr,
    jstring keywords_jstr) {
  if (rgb_array == nullptr || width <= 0 || height <= 0) {
    ThrowJavaException(env, "java/lang/IllegalArgumentException",
                       "Invalid RGB buffer or dimensions");
    return nullptr;
  }

  jsize rgb_len = env->GetArrayLength(rgb_array);
  size_t expected_len = static_cast<size_t>(width) * static_cast<size_t>(height) * 3u;
  if (static_cast<size_t>(rgb_len) != expected_len) {
    ThrowJavaException(env, "java/lang/IllegalArgumentException",
                       "RGB byte length must equal width * height * 3");
    return nullptr;
  }

  const char* opt_cstr = options_json_jstr != nullptr
                             ? env->GetStringUTFChars(options_json_jstr, nullptr)
                             : nullptr;
  const char* lang_cstr = language_jstr != nullptr
                              ? env->GetStringUTFChars(language_jstr, nullptr)
                              : nullptr;
  const char* kw_cstr = keywords_jstr != nullptr
                            ? env->GetStringUTFChars(keywords_jstr, nullptr)
                            : nullptr;

  std::string options_str(opt_cstr != nullptr ? opt_cstr : "{}");
  bool has_lang = lang_cstr != nullptr && lang_cstr[0] != '\0';
  std::string lang_str(has_lang ? lang_cstr : "");
  bool has_kw = kw_cstr != nullptr && kw_cstr[0] != '\0';
  std::string kw_str(has_kw ? kw_cstr : "");

  if (opt_cstr != nullptr) env->ReleaseStringUTFChars(options_json_jstr, opt_cstr);
  if (lang_cstr != nullptr) env->ReleaseStringUTFChars(language_jstr, lang_cstr);
  if (kw_cstr != nullptr) env->ReleaseStringUTFChars(keywords_jstr, kw_cstr);

  std::lock_guard<std::mutex> lock(g_cactus_mutex);
  if ((cactus_models() & CACTUS_VISION) == 0) {
    ThrowJavaException(env, "java/lang/IllegalStateException",
                       "Mirage vision model is not loaded");
    return nullptr;
  }

  EnsureOutputBuffer();
  g_rgb_scratch.resize(expected_len);
  env->GetByteArrayRegion(rgb_array, 0, rgb_len,
                          reinterpret_cast<jbyte*>(g_rgb_scratch.data()));

  // Clear first byte so empty/error buffers never leak prior output.
  g_output_buffer[0] = '\0';

  // Note: cactus_describe returns decoder token count (>= 0) on success and writes
  // a NUL-terminated UTF-8 JSON string into g_output_buffer.
  int token_count_or_err = cactus_describe(
      g_rgb_scratch.data(),
      static_cast<int>(width),
      static_cast<int>(height),
      options_str.c_str(),
      has_lang ? lang_str.c_str() : nullptr,
      has_kw ? kw_str.c_str() : nullptr,
      g_output_buffer.data(),
      static_cast<int>(g_output_buffer.size()));

  if (token_count_or_err < 0) {
    const char* err = cactus_last_error();
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "cactus_describe failed (%d): %s",
                        token_count_or_err, err ? err : "unknown");
    ThrowJavaException(env, "java/lang/IllegalStateException",
                       err ? err : "cactus_describe failed");
    return nullptr;
  }

  size_t json_len = strnlen(g_output_buffer.data(), g_output_buffer.size() - 1);
  jbyteArray out_bytes = env->NewByteArray(static_cast<jsize>(json_len));
  if (out_bytes != nullptr) {
    env->SetByteArrayRegion(out_bytes, 0, static_cast<jsize>(json_len),
                            reinterpret_cast<const jbyte*>(g_output_buffer.data()));
  }
  return out_bytes;
}

JNIEXPORT jdoubleArray JNICALL
Java_com_openetra_app_mirage_MirageNativeBridge_nativeAnalyzeImageQuality(
    JNIEnv* env,
    jclass,
    jbyteArray rgb_array,
    jint width,
    jint height) {
  jdouble result[5] = {128.0, 48.0, 120.0, 0.0, 0.0};
  if (rgb_array == nullptr || width <= 4 || height <= 4) {
    jdoubleArray out = env->NewDoubleArray(5);
    env->SetDoubleArrayRegion(out, 0, 5, result);
    return out;
  }

  jsize rgb_len = env->GetArrayLength(rgb_array);
  size_t expected = static_cast<size_t>(width) * static_cast<size_t>(height) * 3u;
  if (static_cast<size_t>(rgb_len) != expected) {
    jdoubleArray out = env->NewDoubleArray(5);
    env->SetDoubleArrayRegion(out, 0, 5, result);
    return out;
  }

  std::vector<unsigned char> buf(expected);
  env->GetByteArrayRegion(rgb_array, 0, rgb_len, reinterpret_cast<jbyte*>(buf.data()));

  // Downsample stride to <= 256 px wide for sub-millisecond quality evaluation.
  int step = std::max(1, static_cast<int>(width / 256));
  int sw = (width + step - 1) / step;
  int sh = (height + step - 1) / step;
  std::vector<double> luma(static_cast<size_t>(sw) * static_cast<size_t>(sh));

  double sum = 0.0;
  double sum_sq = 0.0;
  size_t overexposed = 0;
  size_t underexposed = 0;
  size_t idx = 0;

  for (int y = 0; y < height; y += step) {
    for (int x = 0; x < width; x += step) {
      size_t off = (static_cast<size_t>(y) * static_cast<size_t>(width) + static_cast<size_t>(x)) * 3u;
      double lum = 0.299 * buf[off] + 0.587 * buf[off + 1] + 0.114 * buf[off + 2];
      luma[idx++] = lum;
      sum += lum;
      sum_sq += lum * lum;
      if (lum > 245.0) overexposed++;
      if (lum < 25.0) underexposed++;
    }
  }

  double count = static_cast<double>(idx);
  double mean = count > 0.0 ? sum / count : 128.0;
  double var = count > 0.0 ? std::max(0.0, (sum_sq / count) - (mean * mean)) : 0.0;

  double lap_sum = 0.0;
  double lap_sq_sum = 0.0;
  size_t lap_count = 0;
  for (int y = 1; y < sh - 1; ++y) {
    for (int x = 1; x < sw - 1; ++x) {
      double c = luma[static_cast<size_t>(y) * sw + x];
      double n = luma[static_cast<size_t>(y - 1) * sw + x];
      double s = luma[static_cast<size_t>(y + 1) * sw + x];
      double w = luma[static_cast<size_t>(y) * sw + (x - 1)];
      double e = luma[static_cast<size_t>(y) * sw + (x + 1)];
      double lap = (n + s + w + e) - 4.0 * c;
      lap_sum += lap;
      lap_sq_sum += lap * lap;
      lap_count++;
    }
  }

  double lap_mean = lap_count > 0 ? lap_sum / lap_count : 0.0;
  double lap_var = lap_count > 0
                       ? std::max(0.0, (lap_sq_sum / lap_count) - (lap_mean * lap_mean))
                       : 120.0;

  result[0] = mean;
  result[1] = std::sqrt(var);
  result[2] = lap_var;
  result[3] = count > 0.0 ? overexposed / count : 0.0;
  result[4] = count > 0.0 ? underexposed / count : 0.0;

  jdoubleArray out = env->NewDoubleArray(5);
  env->SetDoubleArrayRegion(out, 0, 5, result);
  return out;
}

}  // extern "C"
