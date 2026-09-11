#!/usr/bin/env bash
#
# build-release.sh — arma los binarios que se suben a Google Play y App Store.
#
# QUÉ HACE
# --------
#   1. Corre ./scripts/preflight-tiendas.sh (si existe) y NO sigue si falla:
#      compilar 8 minutos para descubrir después que faltaba un client ID es
#      exactamente lo que ese chequeo existe para evitar.
#   2. Lee los --dart-define de .env.release (gitignored) o del entorno.
#   3. Android:  flutter build appbundle --release --obfuscate
#                  --split-debug-info=build/symbols/<version>/android
#   4. iOS:      flutter build ipa --release --obfuscate
#                  --split-debug-info=build/symbols/<version>/ios
#                  --export-options-plist=ios/ExportOptions.plist
#      (si el plist no existe, lo genera con method app-store-connect).
#
# USO
# ---
#   ./scripts/build-release.sh                # las dos plataformas
#   ./scripts/build-release.sh android
#   ./scripts/build-release.sh ios
#   ./scripts/build-release.sh --sin-preflight android
#   ./scripts/build-release.sh --sin-ofuscar  # ver "OFUSCACIÓN"
#   ./scripts/build-release.sh --dry          # imprime los comandos, no compila
#
# DE DÓNDE SALEN LOS --dart-define
# --------------------------------
# `.env.release` en la raíz (formato KEY=VALOR, sin comillas ni `export`), el
# MISMO archivo que lee preflight-tiendas.sh. Copiá .env.release.example y
# completá. Una variable de entorno con el mismo nombre le gana al archivo.
#
# **Una clave vacía no se manda.** `--dart-define=SOCIAL_LOGIN_ENABLED=` no
# significa "usá el default": pisa el default de `bool.fromEnvironment` con
# false y apagaría los botones de Google y Apple en el build que se sube.
#
# OFUSCACIÓN Y SÍMBOLOS — LEER ANTES DE PUBLICAR
# ----------------------------------------------
# `--obfuscate` renombra las clases de Dart en el binario. A cambio, **todo
# stack de Dart que llegue a Crashlytics viene ilegible** y sólo se recupera con
# los símbolos de ESTE build:
#
#   flutter symbolize -d build/symbols/<version>/android/app.android-arm64.symbols \
#     -i stack-que-copiaste-de-crashlytics.txt
#
# Por eso los símbolos van en una carpeta POR VERSIÓN (`2.0.0+20`, no
# `android/` a secas): los de la 2.0.0+20 no sirven para un crash de la
# 2.0.0+21, y pisarlos deja los reportes de la versión anterior sin traducir
# para siempre. Guardá `build/symbols/<version>/` fuera del repo (Drive, el
# mismo lugar que el keystore) apenas termina el build: `build/` está en
# .gitignore y `flutter clean` se lo lleva.
#
# Android además necesita el mapping de R8 (`build/app/outputs/mapping/release/
# mapping.txt`) para los stacks de Java/Kotlin. Con google-services.json
# presente, el plugin `com.google.firebase.crashlytics` lo sube solo; sin él,
# se sube a mano desde la consola de Play/Firebase.
#
# `--sin-ofuscar` existe para el día en que haya que reproducir un crash con
# nombres reales. No es el modo de publicar.
#
# LO QUE ESTE SCRIPT NO HACE
# --------------------------
# No sube nada. El AAB va por Play Console y el IPA por Transporter o
# `xcrun altool`. Tampoco firma iOS por su cuenta: eso lo resuelve Xcode con la
# cuenta del Apple Developer Program (el Personal Team NO puede archivar para
# App Store — ver ENTREGA.md).

set -uo pipefail

cd "$(dirname "$0")/.."
RAIZ="$(pwd)"

CORRER_PREFLIGHT=1
OFUSCAR=1
DRY=0
OBJETIVO="todo"

for arg in "$@"; do
  case "$arg" in
    android|ios|todo) OBJETIVO="$arg" ;;
    --sin-preflight)  CORRER_PREFLIGHT=0 ;;
    --sin-ofuscar)    OFUSCAR=0 ;;
    --dry|--dry-run)  DRY=1; CORRER_PREFLIGHT=0 ;;
    -h|--help) sed -n '2,60p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Argumento desconocido: $arg (probá --help)" >&2; exit 2 ;;
  esac
done

# Con --dry se imprime lo que se iba a correr y se devuelve éxito: sirve para
# revisar los --dart-define antes de gastar diez minutos de compilación.
correr() {
  if [[ "$DRY" == "1" ]]; then
    printf '\033[90m  $ %s\033[0m\n' "$*"
    return 0
  fi
  "$@"
}

rojo()  { printf '\033[31m%s\033[0m\n' "$*"; }
verde() { printf '\033[32m%s\033[0m\n' "$*"; }
gris()  { printf '\033[90m%s\033[0m\n' "$*"; }

titulo() {
  echo
  printf '\033[1m── %s ─────────────────────────────────────────\033[0m\n' "$1"
}

# ── Versión (para la carpeta de símbolos) ──────────────────────────────────
# `version: 2.0.0+20` en pubspec.yaml. Se usa tal cual, con el `+`: es lo que
# identifica el build en Play y en App Store Connect.
VERSION="$(grep -E '^version:' pubspec.yaml | head -1 | sed -E 's/^version:[[:space:]]*//; s/[[:space:]\r]*$//')"
if [[ -z "$VERSION" ]]; then
  rojo "✗ No pude leer 'version:' de pubspec.yaml"
  exit 1
fi

# ── --dart-define ──────────────────────────────────────────────────────────
# Mismo lector que preflight-tiendas.sh: última ocurrencia gana, se toleran
# espacios alrededor del '=', CRLF y comillas.
leer_env_release() {
  local archivo="$RAIZ/.env.release" clave="$1"
  [[ -f "$archivo" ]] || return 1
  grep -E "^[[:space:]]*${clave}[[:space:]]*=" "$archivo" | tail -1 \
    | sed -E "s/^[[:space:]]*${clave}[[:space:]]*=[[:space:]]*//; s/[[:space:]\r]*$//; s/^\"(.*)\"$/\1/; s/^'(.*)'$/\1/"
}

resolver_define() {
  local clave="$1" valor
  valor="${!clave:-}"
  if [[ -z "$valor" ]]; then
    valor="$(leer_env_release "$clave" || true)"
  fi
  printf '%s' "$valor"
}

# Las claves que la app lee con String/bool.fromEnvironment y que tiene sentido
# fijar en un build de tienda. Los defaults de AppConstants ya apuntan a
# producción (Supabase, API), así que no hace falta pasarlos: lo que va acá es
# lo que NO puede quedar en su default.
CLAVES_DEFINE=(
  GOOGLE_IOS_CLIENT_ID
  GOOGLE_SERVER_CLIENT_ID
  TEST_MODE_CODE
  SOCIAL_LOGIN_ENABLED
  LIQUID_GLASS
)

DEFINES=()
titulo "Configuración del build"
echo "· versión: $VERSION"
if [[ -f "$RAIZ/.env.release" ]]; then
  echo "· .env.release encontrado"
else
  gris "· .env.release no existe: los --dart-define salen sólo del entorno"
fi

for clave in "${CLAVES_DEFINE[@]}"; do
  valor="$(resolver_define "$clave")"
  if [[ -z "$valor" ]]; then
    gris "  – $clave sin valor: se usa el default de AppConstants"
    continue
  fi
  DEFINES+=("--dart-define=$clave=$valor")
  # Un client ID no es un secreto, pero el código de modo prueba sí.
  case "$clave" in
    TEST_MODE_CODE) echo "  ✓ $clave = (oculto)" ;;
    *)              echo "  ✓ $clave = $valor" ;;
  esac
done

OFUSCACION=()
if [[ "$OFUSCAR" == "1" ]]; then
  echo "· ofuscación: SÍ (símbolos en build/symbols/$VERSION/)"
else
  rojo "· ofuscación: NO — este build es para depurar, no para publicar"
fi

# ── Preflight ──────────────────────────────────────────────────────────────
if [[ "$CORRER_PREFLIGHT" == "1" && -x "$RAIZ/scripts/preflight-tiendas.sh" ]]; then
  titulo "Preflight"
  if ! "$RAIZ/scripts/preflight-tiendas.sh"; then
    echo
    rojo "✗ El preflight falló: no compilo nada."
    gris "  Arreglá lo que marcó, o corré con --sin-preflight si sabés lo que hacés."
    exit 1
  fi
elif [[ "$CORRER_PREFLIGHT" == "1" ]]; then
  gris "· scripts/preflight-tiendas.sh no existe o no es ejecutable: lo salteo"
fi

FALLOS=0

# ── Android ────────────────────────────────────────────────────────────────
if [[ "$OBJETIVO" == "todo" || "$OBJETIVO" == "android" ]]; then
  titulo "Android — App Bundle"
  OFUSCACION=()
  if [[ "$OFUSCAR" == "1" ]]; then
    OFUSCACION=(--obfuscate --split-debug-info="build/symbols/$VERSION/android")
  fi
  # Sin android/key.properties, bundleRelease se corta a propósito (Play
  # rechaza un AAB firmado con debug). El mensaje lo da el propio Gradle.
  if correr flutter build appbundle --release "${OFUSCACION[@]}" "${DEFINES[@]}"; then
    [[ "$DRY" == "1" ]] || verde "✓ build/app/outputs/bundle/release/app-release.aab"
    if [[ "$OFUSCAR" == "1" ]]; then
      gris "  símbolos Dart: build/symbols/$VERSION/android/"
      gris "  mapping R8:    build/app/outputs/mapping/release/mapping.txt"
    fi
  else
    rojo "✗ El build de Android falló"
    FALLOS=$((FALLOS + 1))
  fi
fi

# ── iOS ────────────────────────────────────────────────────────────────────
if [[ "$OBJETIVO" == "todo" || "$OBJETIVO" == "ios" ]]; then
  titulo "iOS — IPA"

  PLIST="$RAIZ/ios/ExportOptions.plist"
  if [[ ! -f "$PLIST" && "$DRY" == "1" ]]; then
    gris "· ios/ExportOptions.plist no existe: se generaría (--dry: no lo escribo)"
  elif [[ ! -f "$PLIST" ]]; then
    gris "· ios/ExportOptions.plist no existe: lo genero"
    TEAM_ID="$(resolver_define APPLE_TEAM_ID)"
    # `uploadSymbols` sube los dSYM del binario NATIVO a App Store Connect y a
    # Crashlytics. NO cubre los símbolos de Dart de --obfuscate: eso se guarda
    # aparte (ver la cabecera). `signingStyle automatic` deja que Xcode elija el
    # perfil de la cuenta del Developer Program.
    {
      echo '<?xml version="1.0" encoding="UTF-8"?>'
      echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
      echo '<plist version="1.0">'
      echo '<dict>'
      echo '  <key>method</key>'
      echo '  <string>app-store-connect</string>'
      echo '  <key>destination</key>'
      echo '  <string>export</string>'
      echo '  <key>signingStyle</key>'
      echo '  <string>automatic</string>'
      echo '  <key>uploadSymbols</key>'
      echo '  <true/>'
      echo '  <key>uploadBitcode</key>'
      echo '  <false/>'
      echo '  <key>stripSwiftSymbols</key>'
      echo '  <true/>'
      if [[ -n "$TEAM_ID" ]]; then
        echo '  <key>teamID</key>'
        echo "  <string>$TEAM_ID</string>"
      fi
      echo '</dict>'
      echo '</plist>'
    } > "$PLIST"
    if [[ -z "$TEAM_ID" ]]; then
      gris "  (sin APPLE_TEAM_ID en .env.release: el plist va sin <teamID> y Xcode"
      gris "   lo resuelve solo si la Mac tiene una sola cuenta de desarrollador)"
    fi
  fi

  OFUSCACION=()
  if [[ "$OFUSCAR" == "1" ]]; then
    OFUSCACION=(--obfuscate --split-debug-info="build/symbols/$VERSION/ios")
  fi
  if correr flutter build ipa --release "${OFUSCACION[@]}" \
      --export-options-plist="$PLIST" "${DEFINES[@]}"; then
    [[ "$DRY" == "1" ]] || verde "✓ build/ios/ipa/*.ipa"
    if [[ "$OFUSCAR" == "1" ]]; then
      gris "  símbolos Dart: build/symbols/$VERSION/ios/"
    fi
  else
    rojo "✗ El build de iOS falló"
    gris "  Causa más común: la Mac está firmando con el Personal Team, que no"
    gris "  puede archivar para App Store. Hace falta el Apple Developer Program."
    FALLOS=$((FALLOS + 1))
  fi
fi

titulo "Resumen"
if [[ "$FALLOS" -gt 0 ]]; then
  rojo "✗ $FALLOS build(s) fallaron"
  exit 1
fi

verde "✓ Listo"
if [[ "$OFUSCAR" == "1" ]]; then
  echo
  rojo "ANTES DE BORRAR build/: copiá build/symbols/$VERSION/ a un lugar seguro."
  gris "Sin esos archivos, los stacks de Dart de esta versión en Crashlytics"
  gris "quedan ilegibles para siempre."
fi
