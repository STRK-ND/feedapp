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
      // Falls back to debug signing when key.properties is missing so
      // local release builds still work — never ship that APK.
      signingConfig = if (keystoreConfigured)
        signingConfigs.getByName("release")
      else
        signingConfigs.getByName("debug")
    }
  }

  // Gradle emits one APK per ABI per flavor by default; the CI/Play paths
  // produce AABs (per-device delivery), so keep only universal-ish
  // artifacts in outputs to avoid name-collision build failures.
  applicationVariants.all {
    outputs.all {
      (this as com.android.build.gradle.internal.api.BaseVariantOutputImpl)
        .outputFileName = outputFileName.replace("-release", "")
    }
  }
}



dependencies {
  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
  source = "../.."
}