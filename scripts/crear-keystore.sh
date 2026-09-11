#!/usr/bin/env bash
#
# crear-keystore.sh — genera (UNA sola vez) el keystore de subida a Play Store
# y deja android/key.properties listo para `flutter build appbundle --release`.
#
# QUÉ HACE
# --------
#   1. Crea ~/.monaco-keys/ (chmod 700): fuera de todo repo. El ejemplo viejo
#      apuntaba a ../../monaco-release.jks, o sea MSB_FULL/, el wrapper SIN
#      .gitignore: un `git add -A` ahí subía el keystore.
#   2. Genera monaco-release.jks (PKCS12, RSA 2048, 10.000 días, alias `monaco`,
#      DN "O=Monaco Barber Studio, C=AR") con keytool.
#   3. Toma la contraseña de MONACO_KEYSTORE_PASSWORD, la pide por teclado, o
#      genera una al azar si dejás el campo vacío. Es UNA sola para el keystore
#      y para la clave: PKCS12 no admite dos distintas (keytool ignora -keypass
#      con un aviso), así que no se finge que hay dos.
#   4. Escribe android/key.properties con la ruta ABSOLUTA del .jks (chmod 600).
#   5. Imprime el SHA-1 y el SHA-256 del certificado: el SHA-1 lo pide Google
#      Cloud para el client OAuth de tipo Android (Sign in with Google), junto
#      con el applicationId com.monacobarber.monaco_mobile.
#   6. Recuerda hacer backup del .jks + la contraseña.
#
# ES IDEMPOTENTE Y NUNCA PISA UN KEYSTORE: si el .jks ya existe, sólo verifica
# la contraseña, vuelve a imprimir las huellas y escribe key.properties si
# faltaba. Un keystore de subida perdido o pisado significa no poder actualizar
# la app publicada (con Play App Signing se puede reemplazar, pero es un
# trámite con soporte de Play y días de espera).
#
# Uso:
#   ./scripts/crear-keystore.sh                       # interactivo
#   MONACO_KEYSTORE_PASSWORD='…' ./scripts/crear-keystore.sh   # sin preguntar
#
# Variables opcionales:
#   MONACO_KEYSTORE_DIR       carpeta del keystore (default ~/.monaco-keys)
#   MONACO_KEYSTORE_PASSWORD  contraseña (si no está y hay terminal, se pregunta)
#   MONACO_KEY_ALIAS          alias de la clave (default monaco)

set -euo pipefail

cd "$(dirname "$0")/.."
RAIZ="$(pwd)"

DIR="${MONACO_KEYSTORE_DIR:-$HOME/.monaco-keys}"
ALIAS="${MONACO_KEY_ALIAS:-monaco}"
JKS="$DIR/monaco-release.jks"
PROPS="$RAIZ/android/key.properties"
DNAME="CN=Monaco Barber Studio, O=Monaco Barber Studio, C=AR"

rojo()  { printf '\033[31m%s\033[0m\n' "$*" >&2; }
verde() { printf '\033[32m%s\033[0m\n' "$*"; }
gris()  { printf '\033[90m%s\033[0m\n' "$*"; }

# ── keytool ──────────────────────────────────────────────────────────────────
# /usr/bin/keytool en macOS es un stub que falla si no hay JDK. Orden: JAVA_HOME
# → PATH → el JBR de Android Studio → java_home.
KEYTOOL=""
if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/keytool" ]]; then
  KEYTOOL="$JAVA_HOME/bin/keytool"
elif command -v keytool >/dev/null 2>&1 && keytool -help >/dev/null 2>&1; then
  KEYTOOL="$(command -v keytool)"
elif [[ -x "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" ]]; then
  KEYTOOL="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
elif JH="$(/usr/libexec/java_home 2>/dev/null)" && [[ -x "$JH/bin/keytool" ]]; then
  KEYTOOL="$JH/bin/keytool"
fi
if [[ -z "$KEYTOOL" ]]; then
  rojo "No encuentro keytool. Instalá un JDK (brew install --cask temurin) o Android Studio."
  exit 1
fi
# Salida en inglés pase lo que pase: las huellas se buscan por "SHA1:"/"SHA256:".
KT=("$KEYTOOL" -J-Duser.language=en -J-Duser.country=US)

# ── Seguridad mínima antes de escribir nada ──────────────────────────────────
if ! git -C "$RAIZ" check-ignore -q android/key.properties; then
  rojo "android/key.properties NO está ignorado por git en este repo. No sigo:"
  rojo "revisá .gitignore antes de escribir contraseñas ahí."
  exit 1
fi

mkdir -p "$DIR"
chmod 700 "$DIR"

# ── Contraseña ───────────────────────────────────────────────────────────────
PASS="${MONACO_KEYSTORE_PASSWORD:-}"
GENERADA=0
if [[ -z "$PASS" ]]; then
  if [[ ! -t 0 ]]; then
    rojo "Sin terminal y sin MONACO_KEYSTORE_PASSWORD: no puedo pedir la contraseña."
    exit 1
  fi
  if [[ -f "$JKS" ]]; then
    read -r -s -p "Contraseña del keystore existente ($JKS): " PASS
    echo
  else
    read -r -s -p "Contraseña para el keystore nuevo (Enter = generar una al azar): " PASS
    echo
    if [[ -z "$PASS" ]]; then
      # 32 caracteres alfanuméricos: sin símbolos que haya que escapar en
      # key.properties ni en una shell.
      PASS="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)"
      GENERADA=1
    fi
  fi
fi
if [[ ${#PASS} -lt 6 ]]; then
  rojo "keytool exige al menos 6 caracteres de contraseña."
  exit 1
fi
# La contraseña viaja a keytool por variable de entorno (-storepass:env), no por
# argumento: un argumento se ve en `ps` mientras corre.
export MONACO_KT_PASS="$PASS"

# ── Keystore ─────────────────────────────────────────────────────────────────
if [[ -f "$JKS" ]]; then
  gris "Ya existe $JKS: NO lo piso (un keystore de subida no se regenera)."
  if ! "${KT[@]}" -list -keystore "$JKS" -alias "$ALIAS" -storepass:env MONACO_KT_PASS >/dev/null 2>&1; then
    rojo "La contraseña no abre el keystore, o no tiene el alias '$ALIAS'."
    exit 1
  fi
else
  echo "Generando $JKS (RSA 2048, 10.000 días, alias $ALIAS)…"
  "${KT[@]}" -genkeypair \
    -keystore "$JKS" -storetype PKCS12 \
    -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "$DNAME" \
    -storepass:env MONACO_KT_PASS -keypass:env MONACO_KT_PASS
  chmod 600 "$JKS"
  verde "Keystore creado."
fi

# ── android/key.properties ───────────────────────────────────────────────────
# Properties de Java: la única escapatoria que hace falta con contraseñas
# arbitrarias es la barra invertida; `=` y `:` sólo separan en la primera
# aparición, y el valor empieza después.
escapar_prop() { printf '%s' "$1" | sed 's/\\/\\\\/g'; }

if [[ -f "$PROPS" ]]; then
  if grep -q "^storeFile=$(printf '%s' "$JKS" | sed 's/[.[\*^$/]/\\&/g')\$" "$PROPS"; then
    gris "android/key.properties ya apunta a este keystore: lo dejo como está."
  else
    rojo "android/key.properties existe y apunta a OTRO keystore. No lo piso:"
    rojo "  $(grep '^storeFile=' "$PROPS" || true)"
    rojo "Borralo a mano si querés que este script lo reescriba."
    exit 1
  fi
else
  umask 077
  {
    echo "# Generado por scripts/crear-keystore.sh el $(date '+%Y-%m-%d %H:%M'). NO commitear."
    echo "storeFile=$JKS"
    echo "storePassword=$(escapar_prop "$PASS")"
    echo "keyAlias=$ALIAS"
    echo "keyPassword=$(escapar_prop "$PASS")"
  } >"$PROPS"
  chmod 600 "$PROPS"
  verde "Escrito android/key.properties (ruta absoluta, chmod 600)."
fi

# ── Huellas del certificado ──────────────────────────────────────────────────
echo
echo "Huellas del certificado de subida (alias $ALIAS):"
"${KT[@]}" -list -v -keystore "$JKS" -alias "$ALIAS" -storepass:env MONACO_KT_PASS 2>/dev/null \
  | grep -E '^\s*(SHA1|SHA256):' \
  | sed 's/^[[:space:]]*/  /'
unset MONACO_KT_PASS

cat <<EOF

Qué hacer con esto:
  - Google Cloud Console → Credenciales → Crear client OAuth → Android:
    paquete com.monacobarber.monaco_mobile + el SHA-1 de arriba. Sin ese
    client, "Continuar con Google" no anda en el build firmado con esta clave.
    Si Play App Signing re-firma la app (es el default al crear la ficha), en
    Play Console → Integridad de la app aparece OTRO SHA-1 (el de la clave de
    firma de Play): ése también va a Google Cloud, o el login falla en la
    versión de la tienda y anda en la local.
  - Ahora: flutter build appbundle --release
EOF

if [[ $GENERADA -eq 1 ]]; then
  echo
  echo "Contraseña generada (también está en android/key.properties):"
  echo "  $PASS"
fi

cat <<EOF

BACKUP, ahora y no después: copiá $JKS
y la contraseña a un gestor de contraseñas o a un disco que no sea esta Mac.
Sin ese archivo no se puede publicar ninguna actualización de la app.
EOF
