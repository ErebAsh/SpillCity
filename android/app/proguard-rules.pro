# Custom Proguard rules to ignore missing classes in release build
-dontwarn org.slf4j.**

-keep class com.hiennv.flutter_callkit_incoming.** { *; }

# Drift and sqlite3_flutter_libs native bindings
-keep class com.sqlite3.** { *; }
-keep class org.sqlite.** { *; }
-dontwarn com.sqlite3.**
-dontwarn org.sqlite.**
-keepclasseswithmembernames class * {
    native <methods>;
}
