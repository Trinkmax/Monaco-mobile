# Seguridad de los datos (Play Console) — respuesta por respuesta

Actualizado el 10/sep/2026. Play Console → **Contenido de la app → Seguridad de los
datos**. Tiene que ser coherente con `store/privacy-labels.md` (Apple) y con
`https://monacobarber.vercel.app/privacidad`: los tres describen la misma app.

---

## Preguntas generales

| Pregunta | Respuesta |
|---|---|
| ¿Tu app recopila o comparte alguno de los tipos de datos del usuario requeridos? | **Sí** |
| ¿Todos los datos del usuario se cifran en tránsito? | **Sí** — todo va por HTTPS/TLS (Supabase, `/api/mobile/*` en Vercel, FCM, Mercado Pago) |
| ¿Proporcionás una forma de solicitar la eliminación de los datos? | **Sí** → `https://monacobarber.vercel.app/eliminar-cuenta` (y dentro de la app: Perfil → Eliminar mi cuenta) |
| ¿Los datos se recopilan de forma efímera? | No (se guardan) |
| ¿La app está diseñada para familias? | No |

### Sobre "compartido"

Todas las respuestas de abajo van con **compartido = No**. Play define "compartir" como
transferir datos a un tercero, y **excluye expresamente** las transferencias a un
proveedor de servicios que procesa por cuenta del desarrollador. Supabase (base y
autenticación), Meta/WhatsApp Cloud API (el código de acceso y los avisos de turno),
Firebase Cloud Messaging (las notificaciones), Mercado Pago (el cobro de la seña) y
Vercel (el hosting de la API) son exactamente eso. Ninguno usa los datos para
publicidad propia.

---

## Tipos de datos

### Información personal

| Tipo | Recopilado | Compartido | Obligatorio / Opcional | Finalidades |
|---|---|---|---|---|
| **Nombre** | Sí | No | **Obligatorio** | Funciones de la app · Administración de la cuenta · Marketing o promociones |
| **Dirección de correo electrónico** | Sí | No | **Opcional** (sólo si el alta fue con Google o Apple) | Funciones de la app · Administración de la cuenta |
| **Número de teléfono** | Sí | No | **Obligatorio** | Funciones de la app · Administración de la cuenta · Marketing o promociones |
| **IDs de usuarios** | Sí | No | **Obligatorio** | Funciones de la app · Administración de la cuenta · Marketing o promociones |
| Dirección · Raza y etnia · Creencias · Orientación sexual · Otra información personal | No | | | |

"Marketing o promociones" está declarado porque el dashboard manda campañas push
(segmentadas por `client_id`) y difusiones de WhatsApp personalizadas con el nombre al
teléfono del cliente. Es el mismo criterio que el propósito *Developer's Advertising or
Marketing* en la etiqueta de Apple. Si el dueño decide que la app nunca se usa para
marketing, hay que sacarlo de los dos lados **y** dejar de mandar campañas a los
teléfonos y a los tokens que vienen de la app.

### Información financiera

| Tipo | Recopilado | Compartido | Obligatorio / Opcional | Finalidades |
|---|---|---|---|---|
| **Historial de compras** | Sí | No | **Opcional** (sólo si reservás en una sucursal que pide seña) | Funciones de la app |
| Información de pago del usuario | **No** | | | La tarjeta la toma Mercado Pago en el navegador; la app nunca la ve |
| Puntaje crediticio · Otra información financiera | No | | | |

### Ubicación

| Tipo | Recopilado | Por qué |
|---|---|---|
| Ubicación aproximada | **No** | Se usa **en el dispositivo** para ordenar las sucursales por cercanía; no se envía a ningún servidor |
| Ubicación precisa | No | — |

Play mide "recopilado" por si el dato sale del dispositivo, no por si se pide el
permiso. La app pide `ACCESS_COARSE/FINE_LOCATION` y eso hay que explicarlo en la
política de privacidad —ya está—, pero no se declara acá.

### Mensajes · Fotos y videos · Archivos de audio · Contactos · Calendario

**Ninguno.** La app no lee la agenda, la galería, el calendario ni los mensajes.

### Actividad en la app

| Tipo | Recopilado | Compartido | Obligatorio / Opcional | Finalidades |
|---|---|---|---|---|
| **Interacciones con la app** | Sí | No | Obligatorio | Funciones de la app |
| Historial de búsqueda en la app · Apps instaladas · Otro contenido generado por el usuario (ver abajo) · Otras acciones | Ver abajo | | | |
| **Otro contenido generado por el usuario** | Sí | No | **Opcional** | Funciones de la app · Atención al cliente |

"Interacciones con la app" son los turnos, los canjes y las notificaciones leídas.
"Otro contenido generado por el usuario" son las reseñas y comentarios que el cliente
escribe después de un corte; los ve el negocio, no otros usuarios.

### Navegación web

**No se recopila.** La app no tiene navegador embebido.

### Información y rendimiento de la app

| Tipo | Recopilado | Compartido | Obligatorio / Opcional | Finalidades |
|---|---|---|---|---|
| **Registros de fallos** | Sí | No | Obligatorio | Funciones de la app |
| **Diagnóstico** | Sí | No | Obligatorio | Funciones de la app |
| Otros datos de rendimiento | No | | | |

Es Firebase Crashlytics (`pubspec.yaml` + `main.dart`). **Hoy no manda nada** porque
`firebase_options.dart` todavía tiene placeholders y la inicialización se saltea; en
cuanto se corra `flutterfire configure` empieza a funcionar, así que se declara desde
ahora. Si el dueño decide no usarlo, hay que sacar la dependencia y el bloque de
`main.dart` y recién ahí quitarlo de acá.

### Identificadores del dispositivo o de otro tipo

| Tipo | Recopilado | Compartido | Obligatorio / Opcional | Finalidades |
|---|---|---|---|---|
| **IDs de dispositivos o de otro tipo** | Sí | No | Obligatorio | Funciones de la app · Marketing o promociones |

Es el `device_id` propio de la app y el token de FCM (`client_device_tokens`), con los
que se entregan las notificaciones. **No se usa el ID de publicidad de Android**: la app
no incluye ningún SDK de anuncios.

---

## Chequeo antes de enviar

1. Que `https://monacobarber.vercel.app/eliminar-cuenta` responda **200** (al 10/9/2026
   da 404: la página está en el repo del dashboard pero todavía no se deployó).
2. Que la política de privacidad publicada mencione **todos** los tipos de arriba,
   incluidos los registros de fallos, y explique el permiso de ubicación.
3. Que el build que se sube **no** traiga el permiso `AD_ID` por alguna dependencia
   transitiva. Se ve en el manifiesto fusionado
   (`grep AD_ID android/app/build/intermediates/merged_manifests/release/AndroidManifest.xml`)
   o con `aapt2 dump badging` sobre el APK de release. Si aparece, o se declara el uso
   del ID de publicidad en Play Console, o se remueve con
   `<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>`.
