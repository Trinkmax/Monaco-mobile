#!/usr/bin/env bash
#
# preflight-tiendas.sh — chequeo previo a subir la app a App Store / Google Play.
#
# QUÉ HACE
# --------
# Recorre la lista de cosas que, si quedan a medias, hacen que el build se suba
# igual y falle recién en la revisión o en el teléfono del cliente: placeholders
# que nadie reemplazó, el Personal Team en vez del pago, la firma de Android
# ausente, los client IDs de Google que no viajan en el build, los secrets de la
# edge function `client-auth` sin cargar. Imprime un resumen ✓/✗ por ítem y
# termina con exit 1 si CUALQUIER ítem obligatorio falla. Los avisos (⚠) no
# cortan.
#
# No compila nada, no toca nada y no necesita un teléfono: se puede correr en
# cualquier momento, y conviene correrlo ANTES de `flutter build ipa` /
# `flutter build appbundle`.
#
# USO
# ---
#   ./scripts/preflight-tiendas.sh
#   GOOGLE_IOS_CLIENT_ID=… GOOGLE_SERVER_CLIENT_ID=… ./scripts/preflight-tiendas.sh
#   ./scripts/preflight-tiendas.sh --sin-red     # saltea el chequeo contra Supabase
#
# DE DÓNDE SALEN LOS VALORES
# --------------------------
# 1. `.env.release` en la raíz del repo (OPCIONAL, está en .gitignore; formato
#    KEY=VALOR, una por línea, sin comillas ni `export`):
#
#      GOOGLE_IOS_CLIENT_ID=123456789-abcdefg.apps.googleusercontent.com
#      GOOGLE_SERVER_CLIENT_ID=123456789-hijklmn.apps.googleusercontent.com
#
#    Son los mismos valores que hay que pasar al build como
#      --dart-define=GOOGLE_IOS_CLIENT_ID=…  --dart-define=GOOGLE_SERVER_CLIENT_ID=…
#    (ver lib/core/utils/constants.dart y ENTREGA.md §4-bis). El de iOS es el
#    client OAuth "de tipo iOS"; el server es el "de tipo Web". Los dos tienen
#    que estar además en el secret GOOGLE_CLIENT_IDS de la edge function.
#
# 2. Variables de entorno con el mismo nombre. Si están las dos fuentes, gana la
#    variable de entorno (así se puede probar otro valor sin editar el archivo).
#
# 3. `.env` (SUPABASE_URL y SUPABASE_ANON_KEY): se usa sólo para hablar con la
#    edge function `client-auth`. La anon key es pública por diseño.
#
# EL CHEQUEO CONTRA `client-auth`
# -------------------------------
# Manda un `social` con provider google y otro con apple y un id_token basura.
# Respuestas posibles y qué significan:
#   - 503 SOCIAL_VERIFY_UNAVAILABLE → la función NO tiene audiencias cargadas
#     para ese proveedor (secrets GOOGLE_CLIENT_IDS / APPLE_BUNDLE_IDS): en
#     producción el botón social va a fallar SIEMPRE. ✗
#   - 401 SOCIAL_TOKEN_INVALID → los secrets ESTÁN y la función rechazó el token
#     basura, que es exactamente lo que tiene que hacer. ✓
#   - otra cosa (red caída, 429 de rate-limit: 30 por hora por IP) → ✗ con el
#     detalle, porque "no sé" no es "está bien".
# El token basura no tiene 3 segmentos a propósito: la función lo corta ANTES de
# ir a buscar el JWKS de Google/Apple, así el resultado no depende de la red
# hacia ellos y no se consume cuota de nada.

set -uo pipefail

cd "$(dirname "$0")/.."
RAIZ="$(pwd)"

SIN_RED=0
for arg in "$@"; do
  case "$arg" in
    --sin-red) SIN_RED=1 ;;
    -h|--help) sed -n '2,60p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Argumento desconocido: $arg (probá --help)" >&2; exit 2 ;;
  esac
done

# ── Resumen ───────────────────────────────────────────────────────────────────
declare -a RESUMEN=()
FALLAS=0
AVISOS=0

ok()    { RESUMEN+=("  ✓ $1"); }
fallo() { RESUMEN+=("  ✗ $1"); FALLAS=$((FALLAS + 1)); }
aviso() { RESUMEN+=("  ⚠ $1"); AVISOS=$((AVISOS + 1)); }

echo "Preflight de tiendas — Monaco (app de clientes)"
echo "Repo: $RAIZ"
echo

# ── 1. Info.plist sin placeholders ────────────────────────────────────────────
# El REVERSED_CLIENT_ID de Google vive en CFBundleURLTypes; con el placeholder la
# hoja de Google abre y nunca vuelve a la app.
PLIST="ios/Runner/Info.plist"
if grep -q "PLACEHOLDER-REEMPLAZAR" "$PLIST"; then
  fallo "ios/Runner/Info.plist todavía tiene 'PLACEHOLDER-REEMPLAZAR' (URL scheme com.googleusercontent.apps.<REVERSED_CLIENT_ID> del client OAuth de tipo iOS)"
else
  ok "Info.plist sin placeholders"
fi

# ── 2. firebase_options.dart real ─────────────────────────────────────────────
# Con placeholders, main.dart saltea Firebase y el push no existe: la app se sube
# "sin push" y nadie se entera hasta que la primera campaña marca failed.
FB="lib/firebase_options.dart"
if grep -q "PLACEHOLDER" "$FB"; then
  fallo "lib/firebase_options.dart tiene PLACEHOLDER: falta correr 'flutterfire configure' (proyecto Firebase + APNs key)"
else
  ok "firebase_options.dart configurado"
fi

# ── 3. Firma de Android ───────────────────────────────────────────────────────
# Sin key.properties, build.gradle.kts cae a la firma de debug y Play rechaza el
# bundle (o peor: lo acepta como app nueva con otra firma).
if [[ -f "android/key.properties" ]]; then
  ok "android/key.properties existe (firma de release)"
else
  fallo "no existe android/key.properties: sin keystore de release, el appbundle sale firmado con debug (generarlo UNA vez con ./scripts/crear-keystore.sh; ver ENTREGA.md, sección Android)"
fi

# ── 4. Team de Apple ──────────────────────────────────────────────────────────
# A3WAXVR55Z es el Personal Team (Apple ID gratuito): no archiva para App Store
# ni firma push / Sign in with Apple.
PBXPROJ="ios/Runner.xcodeproj/project.pbxproj"
if grep -q "DEVELOPMENT_TEAM = A3WAXVR55Z;" "$PBXPROJ"; then
  fallo "DEVELOPMENT_TEAM sigue siendo A3WAXVR55Z (Personal Team) en $PBXPROJ: hace falta el Team del Apple Developer Program pago (Xcode → Runner → Signing & Capabilities)"
else
  ok "DEVELOPMENT_TEAM no es el Personal Team"
fi

# 4b. Estado del pbxproj: scripts/instalar-en-iphone.sh swapea temporalmente los
# entitlements de Release; si una corrida murió sin restaurar, el archivo queda
# sin push y App Store Connect rechaza el build por entitlements faltantes.
if grep -q "CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease.entitlements;" "$PBXPROJ"; then
  ok "Release/Profile firman con RunnerRelease.entitlements (push + Sign in with Apple)"
else
  fallo "el pbxproj quedó swapeado sin RunnerRelease.entitlements (corrida de instalar-en-iphone.sh que no restauró): git checkout -- $PBXPROJ"
fi

# 4c. Deployment target coherente entre el proyecto y el Podfile.
TARGETS="$(grep -o 'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*' "$PBXPROJ" | sort -u | sed 's/.*= //' | tr '\n' ' ')"
PODFILE_PLAT="$(grep -o "^platform :ios, '[0-9.]*'" ios/Podfile | grep -o "[0-9.]*" | head -1)"
if [[ "$TARGETS" == "15.0 " && "$PODFILE_PLAT" == "15.0" ]]; then
  ok "iOS deployment target 15.0 (pbxproj y Podfile)"
else
  aviso "deployment target: pbxproj=[${TARGETS% }] Podfile=${PODFILE_PLAT:-?} (se esperaba 15.0 en los dos)"
fi

# ── 5. Client IDs de Google para el build ─────────────────────────────────────
# Sin GOOGLE_IOS_CLIENT_ID el botón de Google no se dibuja (a propósito); sin
# GOOGLE_SERVER_CLIENT_ID el SDK autentica pero no emite id_token. Los dos
# viajan como --dart-define, no están en ningún archivo del repo.
leer_env_release() {
  local archivo="$RAIZ/.env.release" clave="$1"
  [[ -f "$archivo" ]] || return 1
  # Última ocurrencia gana; se toleran espacios alrededor del '=' y CRLF.
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

es_client_id_google() {
  [[ "$1" =~ ^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$ ]]
}

if [[ -f "$RAIZ/.env.release" ]]; then
  echo "· .env.release encontrado"
else
  echo "· .env.release no existe (opcional): los --dart-define se leen sólo del entorno"
fi

for CLAVE in GOOGLE_IOS_CLIENT_ID GOOGLE_SERVER_CLIENT_ID; do
  VALOR="$(resolver_define "$CLAVE")"
  if [[ -z "$VALOR" ]]; then
    fallo "falta $CLAVE (variable de entorno o .env.release): el build tiene que llevar --dart-define=$CLAVE=<id>.apps.googleusercontent.com"
  elif es_client_id_google "$VALOR"; then
    ok "$CLAVE = ${VALOR:0:14}…apps.googleusercontent.com"
  else
    fallo "$CLAVE tiene un valor que no parece un client id de Google ('${VALOR:0:24}…'): se espera <número>-<hash>.apps.googleusercontent.com"
  fi
done

# Coherencia extra: el REVERSED_CLIENT_ID del Info.plist tiene que ser el
# client id de iOS invertido. Si los dos existen y no coinciden, la hoja de
# Google vuelve a un esquema que la app no registró.
IOS_ID="$(resolver_define GOOGLE_IOS_CLIENT_ID)"
if [[ -n "$IOS_ID" ]] && es_client_id_google "$IOS_ID" && ! grep -q "PLACEHOLDER-REEMPLAZAR" "$PLIST"; then
  ESPERADO="com.googleusercontent.apps.${IOS_ID%.apps.googleusercontent.com}"
  if grep -q "<string>$ESPERADO</string>" "$PLIST"; then
    ok "Info.plist registra el REVERSED_CLIENT_ID de GOOGLE_IOS_CLIENT_ID"
  else
    fallo "Info.plist no tiene el URL scheme $ESPERADO (el reverso de GOOGLE_IOS_CLIENT_ID)"
  fi
fi

# ── 6. Edge function client-auth: secrets de Google y Apple ───────────────────
if (( SIN_RED )); then
  aviso "client-auth no se consultó (--sin-red)"
else
  SUPABASE_URL_ENV="${SUPABASE_URL:-}"
  SUPABASE_ANON_ENV="${SUPABASE_ANON_KEY:-}"
  if [[ -f "$RAIZ/.env" ]]; then
    [[ -z "$SUPABASE_URL_ENV" ]]  && SUPABASE_URL_ENV="$(grep -E '^SUPABASE_URL=' "$RAIZ/.env" | tail -1 | cut -d= -f2- | tr -d '\r"'"'")"
    [[ -z "$SUPABASE_ANON_ENV" ]] && SUPABASE_ANON_ENV="$(grep -E '^SUPABASE_ANON_KEY=' "$RAIZ/.env" | tail -1 | cut -d= -f2- | tr -d '\r"'"'")"
  fi

  if [[ -z "$SUPABASE_URL_ENV" || -z "$SUPABASE_ANON_ENV" ]]; then
    fallo "no se pudo consultar client-auth: faltan SUPABASE_URL / SUPABASE_ANON_KEY (en .env o en el entorno)"
  elif ! command -v curl >/dev/null 2>&1; then
    fallo "no se pudo consultar client-auth: falta curl"
  else
    ORG_ID="$(grep -A2 "'ORGANIZATION_ID'" lib/core/utils/constants.dart | grep -o "[0-9a-f-]\{36\}" | head -1)"
    ORG_ID="${ORG_ID:-a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11}"
    # 64 chars fijos (la función exige 32..256). No es un secreto real: este
    # device_id nunca llega a crear nada porque el id_token se rechaza antes.
    DEVICE_SECRET="preflight-tiendas-0000000000000000000000000000000000000000000000"
    ENDPOINT="${SUPABASE_URL_ENV%/}/functions/v1/client-auth"

    consultar_social() {
      local provider="$1" body
      body="$(printf '{"action":"social","provider":"%s","id_token":"preflight-no-es-un-jwt","device_id":"preflight-tiendas","device_secret":"%s","org_id":"%s"}' "$provider" "$DEVICE_SECRET" "$ORG_ID")"
      curl -sS --max-time 20 -o "$TMP_BODY" -w '%{http_code}' -X POST "$ENDPOINT" \
        -H "Content-Type: application/json" \
        -H "apikey: $SUPABASE_ANON_ENV" \
        -H "Authorization: Bearer $SUPABASE_ANON_ENV" \
        --data "$body" 2>"$TMP_ERR" || echo "000"
    }

    TMP_BODY="$(mktemp)"; TMP_ERR="$(mktemp)"
    trap 'rm -f "$TMP_BODY" "$TMP_ERR"' EXIT

    for PROV in google apple; do
      case "$PROV" in
        google) SECRETO="GOOGLE_CLIENT_IDS" ;;
        apple)  SECRETO="APPLE_BUNDLE_IDS" ;;
      esac
      STATUS="$(consultar_social "$PROV")"
      CODIGO="$(grep -o '"error":"[A-Z_]*"' "$TMP_BODY" 2>/dev/null | head -1 | cut -d'"' -f4)"
      case "$STATUS:$CODIGO" in
        401:SOCIAL_TOKEN_INVALID)
          ok "client-auth · $PROV: secret $SECRETO cargado (rechazó el token basura con SOCIAL_TOKEN_INVALID)" ;;
        503:SOCIAL_VERIFY_UNAVAILABLE)
          fallo "client-auth · $PROV: SOCIAL_VERIFY_UNAVAILABLE → falta el secret $SECRETO en Supabase (Dashboard → Edge Functions → Secrets, o 'supabase secrets set $SECRETO=…')" ;;
        429:*)
          fallo "client-auth · $PROV: 429 RATE_LIMITED (30 intentos/hora por IP): esperá y volvé a correr" ;;
        000:*)
          fallo "client-auth · $PROV: no se pudo conectar a $ENDPOINT ($(head -c 160 "$TMP_ERR" | tr '\n' ' '))" ;;
        *)
          fallo "client-auth · $PROV: respuesta inesperada HTTP $STATUS ${CODIGO:-sin código} — $(head -c 160 "$TMP_BODY" | tr '\n' ' ')" ;;
      esac
    done
  fi
fi

# ── 7. Versión de pubspec vs último tag (sólo aviso) ──────────────────────────
# Subir dos veces el mismo build number lo rechazan las dos tiendas; acá sólo se
# avisa porque el tag lo pone el coordinador al publicar, no antes.
VERSION_PUBSPEC="$(grep -E '^version:' pubspec.yaml | head -1 | sed 's/^version:[[:space:]]*//' | tr -d '\r')"
if git -C "$RAIZ" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ULTIMO_TAG="$(git -C "$RAIZ" describe --tags --abbrev=0 2>/dev/null || true)"
  if [[ -z "$ULTIMO_TAG" ]]; then
    aviso "pubspec version $VERSION_PUBSPEC · el repo no tiene ningún tag todavía (convención sugerida: v<version>+<build>, p.ej. v$VERSION_PUBSPEC)"
  else
    TAG_LIMPIO="${ULTIMO_TAG#v}"
    if [[ "$TAG_LIMPIO" == "$VERSION_PUBSPEC" ]]; then
      aviso "pubspec version $VERSION_PUBSPEC es la misma que el último tag ($ULTIMO_TAG): si ya se subió, subí el build number (+N) antes de volver a subir"
    else
      ok "pubspec version $VERSION_PUBSPEC (último tag: $ULTIMO_TAG)"
    fi
  fi
else
  aviso "pubspec version $VERSION_PUBSPEC · no es un repo git, no se puede comparar con tags"
fi

# ── Resumen ───────────────────────────────────────────────────────────────────
echo
echo "Resumen:"
printf '%s\n' "${RESUMEN[@]}"
echo
if (( FALLAS > 0 )); then
  echo "✗ $FALLAS ítem(s) obligatorio(s) fallaron ($AVISOS aviso(s)). NO subir a tiendas hasta resolverlos."
  exit 1
fi
if (( AVISOS > 0 )); then
  echo "✓ Todo lo obligatorio está en orden ($AVISOS aviso(s) para mirar)."
else
  echo "✓ Todo en orden."
fi
exit 0
