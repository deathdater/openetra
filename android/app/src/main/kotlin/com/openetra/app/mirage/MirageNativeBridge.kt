package com.openetra.app.mirage

object MirageNativeBridge {
    init {
        System.loadLibrary("openetra_mirage")
    }

    @JvmStatic
    external fun nativeSetThreads(threads: Int)

    @JvmStatic
    external fun nativeIsVisionLoaded(): Boolean

    @JvmStatic
    external fun nativeLoadModelFile(path: String): Int

    @JvmStatic
    external fun nativeDescribeRgb(
        rgb: ByteArray,
        width: Int,
        height: Int,
        optionsJson: String,
        language: String?,
        keywords: String?
    ): ByteArray

    @JvmStatic
    external fun nativeAnalyzeImageQuality(
        rgb: ByteArray,
        width: Int,
        height: Int
    ): DoubleArray
}
