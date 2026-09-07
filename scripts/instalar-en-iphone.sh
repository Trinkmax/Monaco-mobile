#!/usr/bin/env bash
#
# instalar-en-iphone.sh — compila e instala la app en un iPhone conectado por cable.
#
# POR QUÉ EXISTE ESTE SCRIPT
# --------------------------
# La configuración Release del proyecto usa `Runner/RunnerRelease.entitlements`,
# que declara `aps-environment` (Push Notifications). Esa capability SÓLO la puede
# firmar una cuenta del Apple Developer Program pago. Con el Apple ID gratuito
# (Personal Team A3WAXVR55Z) el build muere con:
#
#   "Personal development teams ... do not support the Push Notifications capability"
#
# Para una instalación local eso no cuesta nada: mientras `lib/firebase_options.dart`
# tenga PLACEHOLDER (todavía no se corrió `flutterfire configure`), `main.dart`
# SALTEA la init de Firebase y el push no funciona en ningún caso. Cuando Firebase
# esté configurado y haya Developer Program pago, este script deja de hacer falta:
# `flutter run --release` firma con push directamente.
#
# Entonces el script firma sin push, y para no romper el camino de App Store
# (donde el push SÍ hay que declararlo) el cambio es TEMPORAL: se toca el
# project.pbxproj, se compila, y el `trap` lo restaura pase lo que pase.
#
# LÍMITE DEL APPLE ID GRATUITO: la app CADUCA A LOS 7 DÍAS. Cuando deje de abrir,
# volvé a correr este script. Con el programa pago ($99/año) dura un año, anda el
# push y se puede repartir por TestFlight sin cable.
#
# Uso:  ./scripts/instalar-en-iphone.sh              # release (rápida, standalone)
#       ./scripts/instalar-en-iphone.sh --debug      # debug (hot reload, más lenta)
#       ./scripts/instalar-en-iphone.sh --reinstalar # reinstala lo ya compilado (segundos)
#
# EL IPHONE TIENE QUE ESTAR DESBLOQUEADO al momento de instalar: iOS no deja
# montar la imagen de desarrollo con la pantalla bloqueada y devuelve
# `kAMDMobileImageMounterDeviceLocked`. El script espera hasta 3 minutos a que
# lo desbloquees en vez de morir con ese error.

set -euo pipefail

cd "$(dirname "$0")/.."
RAIZ="$(pwd)"
PBXPROJ="ios/Runner.xcodeproj/project.pbxproj"
BUNDLE_ID="com.monacobarber.monacoMobile"

MODO="release"
case "${1:-}" in
  --debug)      MODO="debug" ;;
  --reinstalar) MODO="reinstalar" ;;
esac

# ── 1. Encontrar el iPhone ────────────────────────────────────────────────────
echo "→ Buscando iPhone conectado..."
UDID="$(flutter devices --machine 2>/dev/null \
  | python3 -c 'import json,sys; d=[x for x in json.load(sys.stdin) if x.get("targetPlatform")=="ios" and not x.get("emulator")]; print(d[0]["id"] if d else "")')"

if [[ -z "$UDID" ]]; then
  echo "✗ No hay ningún iPhone conectado."
  echo "  Conectalo por cable, desbloqueá la pantalla y tocá 'Confiar en esta computadora'."
  exit 1
fi
NOMBRE="$(flutter devices --machine 2>/dev/null \
  | python3 -c 'import json,sys; d=[x for x in json.load(sys.stdin) if x.get("id")=="'"$UDID"'"]; print(d[0]["name"] if d else "iPhone")')"
echo "  ✓ $NOMBRE ($UDID)"

# ── 2. Instalar esperando a que el teléfono esté desbloqueado ─────────────────
instalar_con_espera() {
  local app="$1" intento=0 salida
  while (( intento < 18 )); do            # 18 × 10s = 3 minutos
    if salida="$(xcrun devicectl device install app --device "$UDID" "$app" 2>&1)"; then
      echo "$salida" | tail -3
      return 0
    fi
    if grep -q "DeviceLocked" <<<"$salida"; then
      (( intento == 0 )) && echo "  ⚠ El iPhone está bloqueado. Desbloquealo y dejá la pantalla encendida; espero hasta 3 min..."
      (( intento % 3 == 0 )) && echo "  ... esperando desbloqueo ($(( (18-intento) * 10 ))s restantes)"
      sleep 10; (( intento++ )); continue
    fi
    echo "$salida" >&2
    return 1
  done
  echo "✗ El iPhone siguió bloqueado 3 minutos. Desbloquealo y corré: ./scripts/instalar-en-iphone.sh --reinstalar" >&2
  return 1
}

# ── 3. Swap temporal de entitlements (sin push) ───────────────────────────────
restaurar() {
  if [[ -f "$RAIZ/$PBXPROJ.bak-instalador" ]]; then
    mv "$RAIZ/$PBXPROJ.bak-instalador" "$RAIZ/$PBXPROJ"
    echo "→ project.pbxproj restaurado (push vuelve a estar declarado para App Store)."
  fi
}
trap restaurar EXIT INT TERM

if [[ "$MODO" == "reinstalar" ]]; then
  APP="build/ios/iphoneos/Runner.app"
  [[ -d "$APP" ]] || { echo "✗ No hay build previo en $APP. Corré el script sin --reinstalar."; exit 1; }
  # Un build hecho con --no-codesign (los de QA/simulador) no tiene firma y iOS
  # lo rechaza con "No code signature found" (CoreDeviceError 3002). Mejor
  # decirlo acá que dejar que falle la instalación.
  if ! codesign -dv "$APP" >/dev/null 2>&1; then
    echo "✗ El build en $APP NO está firmado (seguramente salió de un build de QA con --no-codesign)." >&2
    echo "  Corré el script SIN --reinstalar para compilar y firmar de nuevo." >&2
    exit 1
  fi
  echo "→ Reinstalando el build existente (sin recompilar)..."
  instalar_con_espera "$APP"
  xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  echo "✓ Listo. 'Monaco' quedó instalada en $NOMBRE."
  exit 0
fi

# El backup SÓLO se toma si el archivo está en su estado bueno. Sin este guard,
# una corrida que muere sin disparar el trap (kill -9, disco lleno, el pipe que
# se corta) deja el pbxproj swapeado, y la corrida siguiente lo respalda ASÍ y
# después "restaura" el estado malo. Pasó el 7/9/2026: el proyecto quedó dos
# configuraciones sin `aps-environment` y nadie se hubiera enterado hasta que
# App Store Connect rechazara el build por entitlements faltantes.
if ! grep -q "CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease.entitlements;" "$PBXPROJ"; then
  echo "✗ El project.pbxproj ya está swapeado (sin Push) de una corrida anterior que no restauró." >&2
  echo "  Restauralo antes de seguir:  git checkout -- $PBXPROJ" >&2
  exit 1
fi

cp "$PBXPROJ" "$PBXPROJ.bak-instalador"
sed -i '' 's|CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease.entitlements;|CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;|g' "$PBXPROJ"
echo "→ Firmando sin Push Notifications (limitación del Apple ID gratuito)."

# ── 4. Compilar e instalar ────────────────────────────────────────────────────
if [[ "$MODO" == "debug" ]]; then
  echo "→ Compilando en DEBUG y quedando adjunto (Ctrl-C para salir)..."
  flutter run --debug -d "$UDID"
else
  echo "→ Compilando en RELEASE (la primera vez tarda varios minutos)..."
  flutter build ios --release
  APP="build/ios/iphoneos/Runner.app"
  [[ -d "$APP" ]] || { echo "✗ No se generó $APP"; exit 1; }

  echo "→ Instalando en el iPhone..."
  instalar_con_espera "$APP"

  echo "→ Abriendo la app..."
  xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" || \
    echo "  (No se pudo abrir sola: abrila desde la pantalla de inicio.)"

  echo
  echo "✓ Listo. 'Monaco' quedó instalada en $NOMBRE."
  echo "  Si iOS dice 'Desarrollador no confiable':"
  echo "  Ajustes › General › VPN y Administración de dispositivos › confiar en el certificado."
  echo "  Recordá: con Apple ID gratuito la app caduca a los 7 días."
fi
