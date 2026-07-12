import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val requestedReleaseBuild = gradle.startParameter.taskNames.any {
    it.lowercase().contains("release")
}
val versionPropertiesFile = rootProject.file("version.properties")
val versionProperties = Properties()
if (versionPropertiesFile.exists()) {
    versionPropertiesFile.inputStream().use { versionProperties.load(it) }
}
var androidVersionCode = versionProperties.getProperty("VERSION_CODE")?.toIntOrNull() ?: 1
if (requestedReleaseBuild) {
    androidVersionCode += 1
    versionProperties["VERSION_CODE"] = androidVersionCode.toString()
    versionPropertiesFile.outputStream().use {
        versionProperties.store(it, "Auto-incremented for Play Store release builds")
    }
}
val requiredSigningProperties = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingSigningProperties = requiredSigningProperties.filter {
    keystoreProperties.getProperty(it).isNullOrBlank()
}
val releaseStoreFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
val hasReleaseSigning = keystorePropertiesFile.exists() &&
    missingSigningProperties.isEmpty() &&
    releaseStoreFile?.exists() == true

android {
    namespace = "com.buyselladda.app"
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
        applicationId = "com.buyselladda.app"
        minSdk = 23
        targetSdk = 36
        versionCode = androidVersionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = releaseStoreFile
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt"
            )
        }
    }
}

flutter {
    source = "../.."
}

gradle.taskGraph.whenReady { graph ->
    val graphHasReleaseBuild = graph.allTasks.any { it.path.lowercase().contains("release") }
    if (graphHasReleaseBuild && !hasReleaseSigning) {
        val missing = mutableListOf<String>()
        if (!keystorePropertiesFile.exists()) {
            missing += "android/key.properties file is missing"
        }
        if (missingSigningProperties.isNotEmpty()) {
            missing += "missing values in key.properties: ${missingSigningProperties.joinToString(", ")}"
        }
        if (releaseStoreFile?.exists() != true) {
            missing += "keystore file not found at storeFile path"
        }

        throw GradleException(
            "Release signing is not configured for Play Store build.\n" +
                missing.joinToString("\n") { "- $it" } +
                "\nCreate android/key.properties from android/key.properties.example and generate the upload keystore first."
        )
    }
}
