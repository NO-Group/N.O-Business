plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nogroup.business"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.nogroup.business"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val releaseStorePath = System.getenv("NOB_ANDROID_KEYSTORE")
    val releaseStorePassword = System.getenv("NOB_ANDROID_STORE_PASSWORD")
    val releaseKeyPassword = System.getenv("NOB_ANDROID_KEY_PASSWORD")
    val releaseKeyAlias = System.getenv("NOB_ANDROID_KEY_ALIAS") ?: "no-business"
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

flutter {
    source = "../.."
}
