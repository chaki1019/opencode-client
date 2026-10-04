import groovy.json.JsonSlurper
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase values for push (see docs/push-notifications.md). They become the
// string resources the google-services plugin would generate, so FCM can
// start in a cold process to deliver a notification.
val pushEnv: Map<*, *> = rootProject.file("../push.env.json").let {
    if (it.exists()) JsonSlurper().parse(it) as Map<*, *> else emptyMap<Any, Any>()
}

// AdMob app ID (see docs/ads.md). Without ads.env.json the build uses
// Google's sample app ID, which only serves test ads.
val adsEnv: Map<*, *> = rootProject.file("../ads.env.json").let {
    if (it.exists()) JsonSlurper().parse(it) as Map<*, *> else emptyMap<Any, Any>()
}

// Upload key for release builds (see docs/release.md). Codemagic sets the
// CM_KEYSTORE_* variables; locally, android/key.properties holds the same
// values. Without either, release builds fall back to the debug key so
// `flutter run --release` still works.
val keyProperties = Properties().apply {
    rootProject.file("key.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}
fun signingValue(env: String, key: String): String? =
    System.getenv(env)?.takeIf { it.isNotEmpty() } ?: keyProperties.getProperty(key)
val uploadStoreFile = signingValue("CM_KEYSTORE_PATH", "storeFile")

android {
    namespace = "app.opencodemobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // AGP 9 turns resValue off by default; defaultConfig uses it for the
    // Firebase settings from push.env.json and the Crashlytics flag.
    buildFeatures {
        resValues = true
    }

    compileOptions {
        // flutter_local_notifications needs java.time on older Android.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.opencodemobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["admobAppId"] =
            adsEnv["ADMOB_ANDROID_APP_ID"]?.toString()?.takeIf { it.isNotEmpty() }
                ?: "ca-app-pub-3940256099942544~3347511713"

        val firebase = mapOf(
            "google_app_id" to pushEnv["FIREBASE_ANDROID_APP_ID"],
            "google_api_key" to pushEnv["FIREBASE_ANDROID_API_KEY"],
            "gcm_defaultSenderId" to pushEnv["FIREBASE_SENDER_ID"],
            "project_id" to pushEnv["FIREBASE_PROJECT_ID"],
        )
        if (firebase.values.all { !it?.toString().isNullOrEmpty() }) {
            firebase.forEach { (name, value) -> resValue("string", name, value.toString()) }
        }

        // Crashlytics reports Dart errors without its Gradle plugin, which
        // would only add R8 mapping uploads for Java/Kotlin stack traces.
        // Without the plugin there is no build ID, so tell Crashlytics not
        // to insist on one (see docs/support.md).
        resValue("bool", "com.crashlytics.RequireBuildId", "false")
    }

    signingConfigs {
        if (uploadStoreFile != null) {
            create("upload") {
                val password = signingValue("CM_KEYSTORE_PASSWORD", "storePassword")
                val alias = signingValue("CM_KEY_ALIAS", "keyAlias")
                if (password == null || alias == null) {
                    throw GradleException("Upload key is missing its store password or key alias (see docs/release.md).")
                }
                storeFile = file(uploadStoreFile)
                storePassword = password
                keyAlias = alias
                // keytool's default PKCS12 keystores use the store password for
                // the key too, so an empty key password falls back to it.
                keyPassword = signingValue("CM_KEY_PASSWORD", "keyPassword") ?: password
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (uploadStoreFile != null) "upload" else "debug")
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
}
