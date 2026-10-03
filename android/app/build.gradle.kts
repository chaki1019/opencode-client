import groovy.json.JsonSlurper

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

android {
    namespace = "dev.opencodemobile.opencode_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs java.time on older Android.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.opencodemobile.opencode_mobile"
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

        val firebase = mapOf(
            "google_app_id" to pushEnv["FIREBASE_ANDROID_APP_ID"],
            "google_api_key" to pushEnv["FIREBASE_ANDROID_API_KEY"],
            "gcm_defaultSenderId" to pushEnv["FIREBASE_SENDER_ID"],
            "project_id" to pushEnv["FIREBASE_PROJECT_ID"],
        )
        if (firebase.values.all { !it?.toString().isNullOrEmpty() }) {
            firebase.forEach { (name, value) -> resValue("string", name, value.toString()) }
        }
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
}
