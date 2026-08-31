import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load release signing config from `android/key.properties` if it
// exists. That file lives OUTSIDE the git repo (added to
// .gitignore) so the keystore password stays out of source. When
// the file is missing (contributors without the release key, CI
// without secrets) release builds fall back to the debug keystore.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.mytravelpal.mytravelpal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enables desugaring so plugins that need Java 8+ APIs on older
        // Android runtimes (flutter_local_notifications) build cleanly.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.mytravelpal.mytravelpal"
        // flutter_local_notifications' zonedSchedule needs SDK 21+; the
        // default Flutter minSdk is 21 today so this is a no-op most of
        // the time but explicit is better than implicit.
        minSdk = maxOf(21, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        // Only register `release` when `key.properties` is present,
        // so contributors without the release key can still build
        // debug variants without a keystore file lying around.
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Sign with the release keystore when configured. Without
            // it we fall back to the debug signing config so the app
            // still builds — but the resulting APK cannot be shared
            // across devices as an update (signature mismatch). See
            // `key.properties.example` in the repo root for setup.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Android Auto (Car App Library). MyTravelPal ships as a POI
    // Companion — see `project_android_auto` memory. The `-projected`
    // variant is required at runtime to actually connect to the head
    // unit; without it the CarAppService registers but never receives
    // sessions. Version pinned to 1.4.0 — the current stable LTS
    // that supports Android Auto API level 5+.
    implementation("androidx.car.app:app:1.4.0")
    implementation("androidx.car.app:app-projected:1.4.0")
}
