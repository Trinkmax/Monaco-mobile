import java.io.FileInputStream
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Firma de release ────────────────────────────────────────────────────────
// android/key.properties (gitignored) con storeFile/storePassword/keyAlias/
// keyPassword. Lo escribe scripts/crear-keystore.sh; ver android/key.properties.example.
//
// Sin el archivo (máquina de desarrollo, CI sin secretos) hay dos caminos:
// - `flutter build apk --release` (assembleRelease) se firma con la clave de
//   DEBUG y compila igual: sirve para probar en un equipo, NO para Play.
//   `flutter build` corre Gradle con `-q`, así que el aviso va por
//   `logger.quiet`, el único nivel que sobrevive a ese flag (logger.warn y
//   logger.lifecycle no se ven).
// - `flutter build appbundle --release` (bundleRelease) FALLA a propósito:
//   Play rechaza un AAB firmado con debug ("signed in debug mode") y no hay
//   ningún uso legítimo de ese archivo. Para saltear el guard en una prueba:
//     flutter build appbundle --release --android-project-arg=permitirFirmaDebug=true
//   (`-P permitirFirmaDebug=true` es la forma corta; verificado con
//   `flutter build appbundle --help` en Flutter 3.38.4).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
// `storeFile` relativo se resuelve contra android/ (rootProject); el script lo
// escribe absoluto. Un key.properties que apunta a un .jks que no está (máquina
// nueva sin el backup restaurado) cuenta como "sin keystore": el APK se firma
// con debug y el AAB se corta con el mensaje de abajo, en vez de romper
// también `flutter run` en desarrollo.
val storeFileConfigurado = keystoreProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let { rootProject.file(it) }
val hasReleaseKeystore = storeFileConfigurado?.exists() == true
if (storeFileConfigurado != null && !hasReleaseKeystore) {
    logger.quiet(
        "[monaco] android/key.properties apunta a un keystore que no existe: " +
            "${storeFileConfigurado.absolutePath}. Restaurá el backup del .jks en esa ruta " +
            "(o corregí storeFile). Mientras tanto el release se firma con la clave de DEBUG."
    )
}
val permitirFirmaDebug =
    (project.findProperty("permitirFirmaDebug")?.toString() ?: "false").toBoolean()

// El guard corre cuando el grafo de tareas está resuelto y ANTES de compilar
// nada: no espera cinco minutos de R8 para decir que el AAB no sirve. Se mira
// el grafo (y no `gradle.startParameter.taskNames`) para que también atrape
// abreviaturas (`gradlew bR`) y tareas que dependan de bundleRelease.
val rutaProyecto = project.path
gradle.taskGraph.whenReady {
    val pideBundleRelease = allTasks.any { t ->
        t.project.path == rutaProyecto &&
            Regex("^bundle([A-Z][A-Za-z0-9]*)?Release$").matches(t.name)
    }
    if (pideBundleRelease && !hasReleaseKeystore && !permitirFirmaDebug) {
        throw GradleException(
            """
            |
            |[monaco] No se puede armar el App Bundle: falta android/key.properties
            |  (o apunta a un .jks que no existe en esta máquina).
            |
            |  Un AAB firmado con la clave de DEBUG no lo acepta Play Store, así que
            |  este build se corta antes de compilar. Qué hacer:
            |
            |  - Primera vez: ./scripts/crear-keystore.sh (genera el keystore en
            |    ~/.monaco-keys/ y escribe android/key.properties).
            |  - Máquina nueva: restaurá el backup de monaco-release.jks y copiá
            |    android/key.properties.example → android/key.properties con la
            |    ruta ABSOLUTA del .jks y sus contraseñas.
            |  - Sólo para probar el empaquetado (el archivo NO sirve para subir):
            |    flutter build appbundle --release --android-project-arg=permitirFirmaDebug=true
            |
            """.trimMargin()
        )
    }
}

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

    defaultConfig {
        // Application ID publicado: no cambiar después del primer upload a Play.
        applicationId = "com.monacobarber.monaco_mobile"
        minSdk = flutter.minSdkVersion
        // Play exige API 36 para toda subida desde el 31/8/2026. Con Flutter
        // 3.38.4 `flutter.targetSdkVersion` YA es 36 (verificado en
        // packages/flutter_tools/gradle/.../FlutterExtension.kt), así que se deja
        // heredado: fijarlo a mano acá sería congelarlo el día que Flutter suba.
        // Si alguna vez se baja el Flutter del proyecto, revisar este número
        // ANTES de armar el bundle: Play rechaza el upload, no avisa antes.
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
                // `quiet` y no `warn`: es lo único que `flutter build` (Gradle -q)
                // deja pasar. El AAB directamente no se arma (ver el guard arriba).
                // El motivo se distingue: si key.properties está pero apunta a un
                // .jks que falta, el mensaje de arriba ya lo dijo y repetir
                // "no existe" acá mandaba a buscar el archivo equivocado.
                val motivo = if (storeFileConfigurado != null) {
                    "falta el keystore que declara android/key.properties"
                } else {
                    "android/key.properties no existe"
                }
                logger.quiet(
                    "[monaco] $motivo: el release se firma con la " +
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

// `android.kotlinOptions { jvmTarget = … }` está deprecado desde Kotlin 2.x
// (warning en cada configuración; KGP lo va a volver error): va por el DSL
// `compilerOptions` de la extensión `kotlin`, a nivel proyecto. Tiene que
// coincidir con `compileOptions` (Java 17) de arriba.
kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
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
    // Crashlytics va en el MISMO `if`: sin google-services.json no hay proyecto
    // de Firebase al que subir el mapping, y el plugin aborta la configuración.
    // El SDK de Dart (firebase_crashlytics) reporta sin este plugin; lo que se
    // pierde sin él es la deofuscación del stack de R8 y de los símbolos
    // nativos. Con --obfuscate de Dart, además, hay que subir a mano los
    // símbolos de build/symbols/android (ver scripts/build-release.sh).
    apply(plugin = "com.google.firebase.crashlytics")
} else {
    logger.lifecycle("[monaco] android/app/google-services.json no existe: se omiten los plugins google-services y crashlytics (push y telemetría deshabilitados).")
}

// -- Ingreso con Google en Android -------------------------------------------
// `google_sign_in` NO necesita el plugin de arriba ni el google-services.json:
// le alcanza con el `serverClientId` (el client OAuth de tipo **Web**), que la
// app pasa por Dart con --dart-define=GOOGLE_SERVER_CLIENT_ID. Sin ese id el
// SDK autentica pero **no emite id_token** y no hay nada que validar del lado
// del server.
//
// Lo que sí hace falta en la consola de Google Cloud es un client OAuth de tipo
// **Android** con el `applicationId` de arriba y el SHA-1 del keystore de
// release (`keytool -list -v -keystore <store> -alias <alias>`), y también el
// SHA-1 del keystore de debug, o el login sólo anda en el build firmado de
// release. Ese client NO se pasa por Dart: Google lo resuelve por firma.
