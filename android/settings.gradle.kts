pluginManagement {
    // `local.properties` is gitignored, so a fresh clone has none: treat it
    // as optional and fall back to FLUTTER_ROOT (the `flutter` tool
    // always sets it when invoking Gradle). Fail only when neither
    // exists, with an error that says how to fix it.
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            val localProperties = file("local.properties")
            if (localProperties.exists()) {
                localProperties.inputStream().use { properties.load(it) }
            }
            properties.getProperty("flutter.sdk")
                ?: System.getenv("FLUTTER_ROOT")
                ?: error(
                    "Flutter SDK not found: `flutter.sdk` is not set in " +
                        "android/local.properties and FLUTTER_ROOT is not " +
                        "set. Run via `flutter` on PATH (it sets " +
                        "FLUTTER_ROOT), or create android/local.properties " +
                        "with `flutter.sdk=<path-to-flutter>`.",
                )
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.4") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
