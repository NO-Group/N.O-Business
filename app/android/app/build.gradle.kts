plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.n_o_group.mfsl_office"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications for java.time APIs on
        // Android versions below API 26.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.n_o_group.mfsl_office"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val releaseStorePath = System.getenv("MFSL_ANDROID_KEYSTORE")
    val releaseStorePassword = System.getenv("MFSL_ANDROID_STORE_PASSWORD")
    val releaseKeyPassword = System.getenv("MFSL_ANDROID_KEY_PASSWORD")
    val releaseKeyAlias = System.getenv("MFSL_ANDROID_KEY_ALIAS") ?: "com.n_o_group.mfsl_office"
    val hasReleaseSigning = !releaseStorePath.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank() && !releaseKeyPassword.isNullOrBlank()

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeType = "PKCS12"
            }
        }
    }

    buildTypes {
        release {
            // CI/local production builds use the reusable PKCS#12 key supplied
            // through protected environment variables. Debug fallback keeps
            // developer builds available but is never suitable for publishing.
            signingConfig = if (hasReleaseSigning) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
