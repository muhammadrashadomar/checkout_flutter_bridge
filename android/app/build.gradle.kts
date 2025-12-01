plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // Kotlin 2.1.0
    // id("org.jetbrains.kotlin.plugin.compose") // Required for Kotlin 2.x + Compose
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flow_flutter_new"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    // buildFeatures {
    //     compose = true // ✅ Enable Compose
    // }

    kotlinOptions { jvmTarget = JavaVersion.VERSION_11.toString() }

    defaultConfig {
        // TODO: Specify your own unique Application ID
        // (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flow_flutter_new"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter { source = "../.." }

dependencies {}
