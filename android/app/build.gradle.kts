import java.io.FileInputStream
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
  id("com.android.application")
  id("org.jetbrains.kotlin.android")
  id("dev.flutter.flutter-gradle-plugin")
  id("com.google.gms.google-services")
  id("com.google.firebase.crashlytics")
}

val keystoreProperties = Properties().apply {
  val f = rootProject.file("key.properties")
  if (f.exists()) FileInputStream(f).use { load(it) }
}
val keystoreConfigured = keystoreProperties.getProperty("storeFile") != null

android {
  namespace = "com.curatedfeeds"
  compileSdk = flutter.compileSdkVersion
  ndkVersion = flutter.ndkVersion

  compileOptions {
    isCoreLibraryDesugaringEnabled = true
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  kotlin {
    compilerOptions {
      jvmTarget.set(JvmTarget.JVM_17)
    }
  }

  defaultConfig {
    applicationId = "com.curatedfeeds"
    minSdk = flutter.minSdkVersion
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
    multiDexEnabled = true
    ndk {
      // R-5: x86_64 is emulator-only — Play never installs it on a device,
      // and shipping it added ~21 MB to every sideload APK (65.6 MB total).
      // Emulator testing: use a physical device, or run with
      // --target-platform android-arm64 on Apple-silicon hosts.
      abiFilters += listOf("arm64-v8a", "armeabi-v7a")
    }
  }

  // Distribution channels. The Play Store build (play) is the only one
  // published to Google Play: it compiles with PLAY_STORE_BUILD=true (all
  // self-update code paths compile out) and merges the play manifest
  // (no REQUEST_INSTALL_PACKAGES). The direct build keeps GitHub-Releases
  // self-update for sideloaded installs.
  flavorDimensions += "distribution"
  productFlavors {
    create("play") {
      dimension = "distribution"
      resValue("string", "app_name", "Curated Feeds")
    }
    create("direct") {
      dimension = "distribution"
      resValue("string", "app_name", "Curated Feeds Direct")
    }
  }

  buildTypes {
    getByName("release") {
      isMinifyEnabled = true
      isShrinkResources = true
      proguardFiles(
        getDefaultProguardFile("proguard-android-optimize.txt"),
        "proguard-rules.pro",
      )
    }
  }

  signingConfigs {
    if (keystoreConfigured) {
      create("release") {
        keyAlias = keystoreProperties.getProperty("keyAlias")
        keyPassword = keystoreProperties.getProperty("keyPassword")
        storeFile = file(keystoreProperties.getProperty("storeFile"))
        storePassword = keystoreProperties.getProperty("storePassword")
      }
    }
  }

  buildTypes {
    release {
      // L-4: fail closed — a release build without real signing material
      // must not silently produce a debug-signed artifact (re-signable by
      // anyone, cannot upgrade an existing install). The old fallback
      // produced a plausible-looking APK that could be uploaded to a
      // release channel by mistake. Opt in explicitly for local smoke
      // tests with -PallowDebugSigning (CI always provides key.properties
      // via decode_signing, so CI output is unaffected).
      signingConfig = if (keystoreConfigured) {
        signingConfigs.getByName("release")
      } else if (project.hasProperty("allowDebugSigning")) {
        signingConfigs.getByName("debug")
      } else {
        throw GradleException(
          "android/key.properties is missing. Refusing to build a release " +
            "artifact signed with the debug key. Provide real signing " +
            "material, or pass -PallowDebugSigning for a local smoke test.",
        )
      }
    }
  }

  // Name release APKs "Curated Feeds v<version>.apk". versionName comes from
  // pubspec via the Flutter extension, so the filename always tracks the
  // release version. The flavor is not part of the name: the direct channel
  // only ever ships one APK per release, so the version alone is unambiguous.
  // The CI/Play paths produce AABs (per-device delivery), so only the
  // universal APK lands here — no per-ABI name collisions.
  applicationVariants.all {
    val variantVersion = flutter.versionName
    outputs.all {
      (this as com.android.build.gradle.internal.api.BaseVariantOutputImpl)
        .outputFileName = "Curated Feeds v$variantVersion.apk"
    }
  }
}



dependencies {
  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
  source = "../.."
}