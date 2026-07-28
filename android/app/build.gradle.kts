import java.io.FileInputStream
import java.util.Properties

plugins {
  id("com.android.application")
  id("org.jetbrains.kotlin.android")
  id("dev.flutter.flutter-gradle-plugin")
  id("com.google.gms.google-services")
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

  kotlinOptions {
    jvmTarget = "17"
  }

  defaultConfig {
    applicationId = "com.curatedfeeds"
    minSdk = flutter.minSdkVersion
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
    multiDexEnabled = true
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
}



dependencies {
  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
  source = "../.."
}