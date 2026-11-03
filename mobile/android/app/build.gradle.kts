import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clé d'envoi Play Store : android/key.properties (jamais dans git), écrit par
// Codemagic ou à la main. Sans ce fichier, la version release est signée avec la
// clé de debug (tests en local seulement, refusée par le Play Store).
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.letterbattle.letter_battle"
    // Agora / permission_handler : compileSdk ≥ 37.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // Aligné sur l'App ID / Play Console (même id que iOS Bundle ID).
        applicationId = "com.letterbattle.letterBattle"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Identifiant d'application AdMob (forme ca-app-pub-…~… avec un tilde).
        // Pas l'ID d'un bloc (…/…). Vide / absent → ID de test Google.
        val admobAppId = sequenceOf(
            project.findProperty("ADMOB_APP_ID") as String?,
            System.getenv("ADMOB_APP_ID"),
        ).mapNotNull { it?.trim()?.takeIf(String::isNotEmpty) }
            .firstOrNull()
            ?: "ca-app-pub-3940256099942544~3347511713"
        require(admobAppId.contains('~')) {
            "ADMOB_APP_ID invalide « $admobAppId ». " +
                "Il faut l'ID d'application AdMob (ca-app-pub-…~…), " +
                "pas l'ID d'un bloc Rewarded/Interstitiel (…/…)."
        }
        manifestPlaceholders["admobAppId"] = admobAppId
    }

    signingConfigs {
        if (keyProperties.isNotEmpty()) {
            create("upload") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    // Vocal Agora : on n'utilise que la voix. Les extensions vidéo, visage, lèvres, son 3D…
    // ne sont jamais chargées (aucune bibliothèque gardée n'en dépend) : environ 20 Mo de
    // moins à télécharger. On garde la réduction de bruit et l'annulation d'écho.
    packaging {
        jniLibs {
            // Évite UnsatisfiedLinkError sur certains téléphones via AAB Play Store.
            useLegacyPackaging = true
            excludes += listOf(
                "lib/*/libagora_lip_sync_extension.so",
                "lib/*/libagora_clear_vision_extension.so",
                "lib/*/libagora_spatial_audio_extension.so",
                "lib/*/libagora_segmentation_extension.so",
                "lib/*/libagora_face_capture_extension.so",
                "lib/*/libagora_face_detection_extension.so",
                "lib/*/libagora_audio_beauty_extension.so",
                "lib/*/libagora_content_inspect_extension.so",
                "lib/*/libagora_video_quality_analyzer_extension.so",
                "lib/*/libagora_video_av1_encoder_extension.so",
                "lib/*/libagora_video_encoder_extension.so",
                "lib/*/libagora_screen_capture_extension.so",
            )
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyProperties.isNotEmpty()) {
                signingConfigs.getByName("upload")
            } else {
                signingConfigs.getByName("debug")
            }
            // Même sans minifyEnabled, R8 peut shrinker les libs : garder WorkManager.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
    // google_mobile_ads tire un vieux WorkManager qui plante au démarrage
    // en release (InitializationProvider / WorkDatabase) sur Android récents.
    implementation("androidx.work:work-runtime:2.11.2")
}
