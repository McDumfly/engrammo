import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: put your keystore details in android/key.properties
// (gitignored — never commit it). Release builds REFUSE to run without
// that file (see the taskGraph check below): silently shipping a
// release signed with debug keys is worse than a loud error.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}

android {
    namespace = "com.engrammo.engrammo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.engrammo.engrammo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Real keys when android/key.properties exists. Without it the
            // taskGraph check below fails the build loudly instead of
            // silently signing the release with debug keys.
            val hasReleaseKeys =
                keystoreProperties.getProperty("storeFile") != null
            signingConfig = signingConfigs.getByName(
                if (hasReleaseKeys) "release" else "debug",
            )
        }
    }
}

// Fail LOUDLY when a release task runs without android/key.properties.
// This runs at task-graph time (not configuration time) so plain debug
// builds keep working on a fresh clone.
gradle.taskGraph.whenReady {
    val wantsRelease = allTasks.any { it.name.contains("Release") }
    if (wantsRelease && keystoreProperties.getProperty("storeFile") == null) {
        throw GradleException(
            "Release build needs a real signing config: create " +
                "android/key.properties with storeFile/storePassword/" +
                "keyAlias/keyPassword (see https://flutter.dev/to/reference-keystore). " +
                "The file is gitignored — never commit it. Refusing to " +
                "sign a release with debug keys.",
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
