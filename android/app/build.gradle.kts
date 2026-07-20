import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.isFile) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

// Local releases use android/key.properties. CI can provide the same values as
// environment variables without writing passwords to the checkout.
fun releaseSigningValue(propertyName: String, environmentName: String): String? =
    System.getenv(environmentName)?.trim()?.takeIf { it.isNotEmpty() }
        ?: keystoreProperties.getProperty(propertyName)?.trim()?.takeIf { it.isNotEmpty() }

val releaseStoreFilePath = releaseSigningValue("storeFile", "PARKD_ANDROID_KEYSTORE_PATH")
val releaseStorePassword = releaseSigningValue(
    "storePassword",
    "PARKD_ANDROID_KEYSTORE_PASSWORD",
)
val releaseKeyAlias = releaseSigningValue("keyAlias", "PARKD_ANDROID_KEY_ALIAS")
val releaseKeyPassword = releaseSigningValue(
    "keyPassword",
    "PARKD_ANDROID_KEY_PASSWORD",
)
val releaseStoreFile = releaseStoreFilePath?.let(rootProject::file)
val hasReleaseSigning =
    releaseStoreFile?.isFile == true &&
        releaseStorePassword != null &&
        releaseKeyAlias != null &&
        releaseKeyPassword != null

gradle.taskGraph.whenReady {
    if (
        !hasReleaseSigning &&
        allTasks.any { task -> task.path.lowercase().contains("release") }
    ) {
        throw GradleException(
            "Release signing is not configured. Copy android/key.properties.example " +
                "to android/key.properties (or set the PARKD_ANDROID_* environment " +
                "variables) and provide a valid Play upload keystore.",
        )
    }
}

android {
    namespace = "app.parkd.mobile"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "app.parkd.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            ndk {
                // Google Play can use this archive to symbolize native crashes.
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }
}

flutter {
    source = "../.."
}
