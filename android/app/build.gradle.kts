import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Firma de release ────────────────────────────────────────────────────────
// android/key.properties (gitignored) con storeFile/storePassword/keyAlias/
// keyPassword. Ver android/key.properties.example. Si el archivo no existe
// (máquina de desarrollo, CI sin secretos) el release se firma con la clave
// de debug para que `flutter build apk --release` siga compilando; ESE build
// NO sirve para Play Store, y el log lo avisa.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists() &&
    !keystoreProperties.getProperty("storeFile").isNullOrBlank()

android {
    namespace = "com.monacobarber.monaco_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications (>= 10) usa java.time: necesita desugaring
        // en la app, no alcanza con que lo tenga el plugin.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Application ID publicado: no cambiar después del primer upload a Play.
        applicationId = "com.monacobarber.monaco_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "[monaco] android/key.properties no existe: el release se firma con la " +
                        "clave de DEBUG. Sirve para probar en un equipo, NO para subir a Play Store."
                )
                signingConfigs.getByName("debug")
            }
            // El plugin de Flutter ya prende minify + shrinkResources en release;
            // acá sólo sumamos las reglas propias (GSON de flutter_local_notifications).
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// ── Firebase (FCM) ──────────────────────────────────────────────────────────
// El plugin google-services se aplica SÓLO si existe android/app/google-services.json
// (lo genera `flutterfire configure`). Sin el archivo, el plugin aborta el build;
// con esta guarda la app compila igual y el push queda en placeholders hasta que
// el dueño configure Firebase. Mismo criterio en iOS: GoogleService-Info.plist
// es opcional porque main.dart inicializa Firebase con firebase_options.dart.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle("[monaco] android/app/google-services.json no existe: se omite el plugin google-services (push deshabilitado).")
}
