import java.util.Properties

// Release signing credentials, kept outside the repository.
//
// `android/key.properties` holds the keystore path and its passwords. It is
// git-ignored, and so is the keystore itself: a signing key is the thing that
// proves an update came from you, and Play will not accept an app signed by
// anyone else afterwards — losing it or leaking it are both unrecoverable for
// that listing.
//
// Absent, the release build falls back to debug signing so `flutter run
// --release` still works on a machine that has no key. That fallback must
// never reach Play, which rejects debug-signed uploads outright.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

// Resolved here rather than at the call site so the failure mode is a clear
// message instead of Gradle hunting for a mangled path inside `app/`.
//
// **Backslashes are escape characters in a .properties file.** A Windows path
// written the natural way — `E:\FlutterProjects\jks\key.jks` — loses every
// one of them on load and arrives as `E:FlutterProjectsjkskey.jks`, which then
// resolves relative to the module directory. Forward slashes work fine on
// Windows and avoid the trap entirely, so they are what the example shows; a
// path that still has backslashes is normalised here rather than failing.
val releaseKeystore: File? = keystoreProperties
    .getProperty("storeFile")
    ?.replace("\\", "/")
    ?.let { path ->
        val candidate = File(path)
        if (candidate.isAbsolute) candidate else rootProject.file(path)
    }
    ?.takeIf(File::exists)

val hasReleaseKey = releaseKeystore != null

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vehiclecare.vehicle_care"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications, which uses java.time APIs
        // that need desugaring below API 26.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.vehiclecare.vehicle_care"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_local_notifications requires API 21+; Flutter's default is
        // already higher, but pinning it makes the requirement explicit.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        multiDexEnabled = true
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = releaseKeystore
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                // No key on this machine. Keeps `flutter run --release`
                // working; a build produced this way cannot be published.
                signingConfigs.getByName("debug")
            }

            // Shrinking is what makes the release build meaningfully smaller
            // than the debug one. Flutter ships the ProGuard rules its own
            // plugins need, so this is safe without a hand-written config.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
