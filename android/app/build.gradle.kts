import java.util.Properties
import java.io.FileInputStream
import com.android.build.gradle.internal.api.ApkVariantOutputImpl

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
// Real keystore when key.properties is present (local/release machines); fall
// back to debug signing so CI and keystore-less contributors can still run the
// release compile gate. Chosen here, not inline, so the release type's
// `signingConfig` stays the one space-free line F-Droid's build strips — its
// APK must come out unsigned, not debug-signed (docs/fdroid.md § F-Droid's
// signing stripper must leave an unsigned build).
val releaseSigningConfig = if (keystorePropertiesFile.exists()) "release" else "debug"

android {
    namespace = "com.invoiceninja.admin"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.invoiceninja.admin"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(releaseSigningConfig)
        }
    }

    // The dependency-metadata block AGP writes into a signed APK is encrypted
    // to Google, so F-Droid flags it. Play reads the bundle's copy, which stays.
    dependenciesInfo {
        includeInApk = false
    }
}

// F-Droid's split-APK versionCode: build * 10 + ABI digit, overriding Flutter's
// <digit> * 1000 + build so a new release outranks every ABI of an old one
// (docs/fdroid.md § The F-Droid recipe). Runs after Flutter's own override,
// which the plugin registers when it is applied above.
val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abiVersionCode = abiCodes[output.filters.find { it.filterType == "ABI" }?.identifier]
        if (abiVersionCode != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride = variant.versionCode * 10 + abiVersionCode
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
