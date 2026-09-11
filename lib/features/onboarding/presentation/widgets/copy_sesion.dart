/// Texto único del diálogo "¿Cerrar sesión?".
///
/// Vive acá porque lo comparten tres pantallas (el gate de biometría, el de
/// PIN y Perfil) y hasta el 10/sep/2026 decían **tres cosas distintas**, dos de
/// ellas falsas: "vas a tener que ingresar tu número y un código de WhatsApp".
/// Ese código no llega: `clearSession()` conserva el `device_secret` a
/// propósito, así que `start` reconoce el dispositivo y devuelve la sesión sin
/// mandar nada (login silencioso). La pantalla del teléfono ya lo decía al
/// derecho —"Si ya entraste desde este teléfono, pasás directo y no te mandamos
/// nada"— y la app se contradecía a sí misma.
///
/// Prometer un código de más también sugiere que cerrar sesión "protege" la
/// cuenta en un teléfono prestado, y no es así: en ese equipo, quien tipee el
/// número entra. Que sea deseable o no es una decisión de producto (habría que
/// rotar el `device_secret` en `signOut()`); mientras no se tome, el texto
/// tiene que describir lo que pasa de verdad.
const String kCerrarSesionDetalle =
    'Volvés a la pantalla de bienvenida. Para entrar de nuevo usás tu número, '
    'Google o Apple: como este teléfono ya es conocido, no te vamos a pedir '
    'ningún código.';
