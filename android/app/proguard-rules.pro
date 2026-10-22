# JNI name lookups used by shared_preferences_android 2.5.1 / jni 1.1.0.
# Upstream fix: https://github.com/flutter/packages/pull/13311
# Keep only these interop types; R8 remains enabled for the release app.
# Remove when the pinned dependencies ship the upstream consumer rules.
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
