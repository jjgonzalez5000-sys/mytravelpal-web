plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
