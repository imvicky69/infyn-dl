# Proguard rules for Infyn DL

# Keep Flutter Engine and Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep App native downloader classes
-keep class com.example.media_downloader.** { *; }
-keepclassmembers class com.example.media_downloader.** { *; }

# Keep youtubedl-android & ffmpeg
-keep class com.yausername.** { *; }
-keepclassmembers class com.yausername.** { *; }
-keep class io.github.junkfood02.** { *; }
-keepclassmembers class io.github.junkfood02.** { *; }

# Keep Kotlin coroutines & reflection
-keep class kotlinx.coroutines.** { *; }
-keepclassmembers class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**
