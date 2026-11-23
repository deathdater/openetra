# Keep Openetra JNI / Cactus native bridge methods
-keep class com.openetra.app.mirage.MirageNativeBridge {
    native <methods>;
    public static <methods>;
}
-keep class com.openetra.app.** { *; }

# Keep sherpa-onnx JNI classes and callbacks
-keep class com.k2fsa.sherpa.onnx.** { *; }

# Keep Tesseract4Android JNI classes
-keep class com.googlecode.tesseract.android.** { *; }

# Keep LiteRT / TensorFlow Lite interpreter runtime
-keep class org.tensorflow.lite.** { *; }

# Keep Google ML Kit vision / text / barcode components
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn org.tensorflow.lite.**
