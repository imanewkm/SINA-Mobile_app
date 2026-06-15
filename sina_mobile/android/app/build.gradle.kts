plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.sina.sina_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (uses java.time on older APIs).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.sina.mobility"
        // SINA targets budget phones; minSdk 24 per project spec.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a"))
        }
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter build apk --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Disable R8/shrinking: we use TFLite via FFI (no reflection) and the
            // optional GPU delegate classes aren't on the classpath.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// tflite_flutter pulls TensorFlow Lite 2.11.0, whose AARs share the
// 'org.tensorflow.lite' namespace and break AGP 8's manifest merger.
// Force newer artifacts that declare unique namespaces.
configurations.all {
    resolutionStrategy {
        force("org.tensorflow:tensorflow-lite:2.16.1")
        force("org.tensorflow:tensorflow-lite-api:2.16.1")
        force("org.tensorflow:tensorflow-lite-gpu:2.16.1")
        force("org.tensorflow:tensorflow-lite-gpu-api:2.16.1")
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
