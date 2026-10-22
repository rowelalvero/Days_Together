import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Release signing credentials live in android/key.properties, which is
// gitignored and must never be committed. Without it a release build (apk or
// app bundle) FAILS rather than silently signing with the debug key (audit
// F-23): a debug-signed release is not publishable and is easy to ship by
// mistake. To build one deliberately for local testing:
//   ALLOW_DEBUG_SIGNED_RELEASE=true flutter run --release
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists() &&
    keystoreProperties.getProperty("storeFile") != null

val allowDebugSignedRelease = System.getenv("ALLOW_DEBUG_SIGNED_RELEASE") == "true"

if (!hasReleaseKeystore && allowDebugSignedRelease) {
    logger.warn(
        "WARNING: android/key.properties not found -- ALLOW_DEBUG_SIGNED_RELEASE is set, so " +
            "release builds are signed with the DEBUG keystore and CANNOT be uploaded to the Play Store."
    )
}

gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any {
        it.name == "assembleRelease" || it.name == "bundleRelease"
    }
    if (buildsRelease && !hasReleaseKeystore && !allowDebugSignedRelease) {
        throw GradleException(
            "Release signing is not configured: android/key.properties is missing. " +
                "Add it to build a publishable release, or set " +
                "ALLOW_DEBUG_SIGNED_RELEASE=true for a local-only debug-signed build."
        )
    }
}

android {
    namespace = "com.szacheo.days_together"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.szacheo.days_together"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                hasReleaseKeystore -> signingConfigs.getByName("release")
                allowDebugSignedRelease -> signingConfigs.getByName("debug")
                else -> null // the taskGraph guard above stops the build first
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
