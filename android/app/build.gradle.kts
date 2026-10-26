import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release builds are signed with the project's own key, configured through
// android/key.properties (git-ignored, relative to this directory):
//
//   storeFile=flutter-release.jks
//   storePassword=...
//   keyAlias=...
//   keyPassword=...
//   storeType=JKS          # optional, JKS or PKCS12
//
// The release workflow writes this file from repository secrets and sets
// REQUIRE_RELEASE_SIGNING=true so a missing keystore fails the build instead of
// silently producing a debug-signed APK. Local release builds without the file
// fall back to the debug keystore, keeping `flutter run --release` working.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

if (hasReleaseKeystore) {
    val missing = listOf("storeFile", "storePassword", "keyAlias").filter {
        keystoreProperties.getProperty(it).isNullOrBlank()
    }
    if (missing.isNotEmpty()) {
        throw GradleException(
            "android/key.properties is missing required entries: ${missing.joinToString()}",
        )
    }
}

if (System.getenv("REQUIRE_RELEASE_SIGNING") == "true" && !hasReleaseKeystore) {
    throw GradleException(
        "android/key.properties is missing but REQUIRE_RELEASE_SIGNING=true. " +
            "Restore the release keystore secrets before building.",
    )
}

android {
    namespace = "com.example.kemoshow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.kemoshow"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                    ?: keystoreProperties.getProperty("storePassword")
                keystoreProperties.getProperty("storeType")?.let { storeType = it }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Fallback so `flutter run --release` works without secrets.
                signingConfigs.getByName("debug")
            }
        }
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
