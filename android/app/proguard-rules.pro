# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Maps
-keep class com.google.android.gms.maps.** { *; }

# Hive
-keep class com.hive.** { *; }

# Play Core (referenced by Flutter engine deferred components, not used in this app)
-dontwarn com.google.android.play.core.**
