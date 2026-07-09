# Keep Flutter engine hooks.
-keep class io.flutter.** { *; }
-keep interface io.flutter.** { *; }
-dontwarn io.flutter.**

# AppsFlyer / Firebase reflection surface — leave untouched.
-keep class com.appsflyer.** { *; }
-keep interface com.appsflyer.** { *; }
-keep class com.google.firebase.** { *; }
-keep interface com.google.firebase.** { *; }

# WebView JS-bridge callbacks are looked up by name.
-keepattributes JavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Local notifications' scheduler classes are pulled via reflection.
-keep class com.dexterous.** { *; }
