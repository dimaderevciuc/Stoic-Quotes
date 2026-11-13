# ONNX Runtime's native library (libonnxruntime4j_jni.so) looks up its Java classes,
# fields and methods by name through JNI. If R8 renames or strips them, FindClass
# returns null and the app aborts with "JNI DETECTED ERROR ... java_class == null"
# the first time a model runs. Keep the whole package as-is.
-keep class ai.onnxruntime.** { *; }
-keepclassmembers class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**
