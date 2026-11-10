plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.stellasora.tracker.stella_tracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.stellasora.tracker.stella_tracker"
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

dependencies {
    implementation("com.google.mlkit:text-recognition:16.0.1")
}

flutter {
    source = "../.."
}

// Copia el APK generado como "Stella-Trekkers-<tipo>.apk" junto al original.
tasks.whenTaskAdded {
    val variant = when (name) {
        "assembleDebug" -> "debug"
        "assembleRelease" -> "release"
        else -> null
    }
    if (variant != null) {
        doLast {
            val outDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
            val src = layout.buildDirectory.file("outputs/apk/$variant/app-$variant.apk").get().asFile
            if (src.exists()) {
                outDir.mkdirs()
                src.copyTo(File(outDir, "Stella-Trekkers-$variant.apk"), overwrite = true)
            }
        }
    }
}
