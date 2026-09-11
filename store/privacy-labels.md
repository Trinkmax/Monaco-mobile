# App Privacy (App Store Connect) — respuesta por respuesta

Actualizado el 10/sep/2026. **Esto y `ios/Runner/PrivacyInfo.xcprivacy` tienen que decir
lo mismo**: Apple cruza el manifiesto de privacidad del binario (y el de cada SDK) con
las etiquetas de la ficha, y una diferencia frena la entrega.

Regla que se usó para decidir qué se "recolecta" (Apple y Google la definen igual): un
dato cuenta sólo si **sale del teléfono** hacia nuestros servidores o los de un tercero.
Lo que se usa únicamente en el dispositivo no se declara.

- **Data used to track you**: **ninguno.** No hay SDK de publicidad, no se lee el IDFA,
  no se cruza con datos de terceros. `NSPrivacyTracking = false` y sin dominios de
  tracking en el manifiesto. → En la pregunta *"Do you or your third-party partners use
  data for tracking purposes?"* responder **No**.
- **Data linked to you**: todo lo de abajo salvo los diagnósticos.
- **Data not linked to you**: los diagnósticos de Crashlytics.

---

## Contact Info

| Tipo | ¿Se recolecta? | Linked | Tracking | Propósitos | De dónde sale |
|---|---|---|---|---|---|
| **Phone Number** | Sí | Sí | No | App Functionality · Developer's Advertising or Marketing | Es LA identidad del cliente (`clients.phone`, alta por OTP de WhatsApp). Marketing porque las difusiones de WhatsApp del dashboard se mandan a ese número (`src/lib/actions/broadcasts.ts`) |
| **Name** | Sí | Sí | No | App Functionality · Developer's Advertising or Marketing | `clients.name`, lo escribe el cliente o lo trae Google/Apple. Marketing porque las difusiones reemplazan `{{nombre}}` con este dato |
| **Email Address** | Sí | Sí | No | App Functionality | Sólo si el alta fue con Google o Apple (`clients.email`, migración 210). El relay de Apple sigue siendo un email. **Sin marketing**: verificado que ningún código del dashboard le manda mails a clientes |
| Physical Address | No | | | | |
| Other User Contact Info | No | | | | |

## Health & Fitness · Financial Info (salvo compras) · Contacts · Browsing History · Search History · Sensitive Info

**Ninguno.** En particular:

- **Payment Info: NO.** La seña se paga en el navegador del sistema, en Mercado Pago. La
  app nunca ve la tarjeta.
- **Contacts: NO.** Invitar a un amigo comparte un código con la hoja del sistema; la app
  no lee la agenda.

## Location

| Tipo | ¿Se recolecta? | Por qué |
|---|---|---|
| Precise Location | No | — |
| **Coarse Location** | **No** | `lib/core/location/` pide la posición **sólo** para ordenar las sucursales por cercanía con `Geolocator.distanceBetween` **en el teléfono** (`branch_picker_step.dart`). Ningún endpoint de `lib/core/api/` manda lat/lng. El permiso sí se pide (`NSLocationWhenInUseUsageDescription`), pero pedir un permiso no es recolectar. **Si algún día la ubicación viaja al server, hay que declararla acá y en el manifiesto.** |

## User Content

| Tipo | ¿Se recolecta? | Linked | Tracking | Propósitos |
|---|---|---|---|---|
| **Customer Support** | Sí | Sí | No | App Functionality |
| **Other User Content** | Sí | Sí | No | App Functionality · Customer Support |

Son las reseñas internas y los comentarios que el cliente escribe después de un corte
(`client_reviews`, `crm_cases`). Nadie más que el negocio los ve: no hay contenido de un
usuario visible para otro.

| Photos or Videos · Audio Data · Gameplay Content · Emails or Text Messages | No |
|---|---|

## Identifiers

| Tipo | ¿Se recolecta? | Linked | Tracking | Propósitos | De dónde sale |
|---|---|---|---|---|---|
| **User ID** | Sí | Sí | No | App Functionality · Developer's Advertising or Marketing | `clients.id` / `auth.uid()` y el `subject` de Google/Apple. Marketing porque las campañas push eligen la audiencia por `client_id` |
| **Device ID** | Sí | Sí | No | App Functionality · Developer's Advertising or Marketing | El `device_id` propio de la app (**no** el IDFA/IDFV: no se leen) y el token FCM, que viajan en `client-auth` y en `POST /api/mobile/push/token` |

## Purchases

| Tipo | ¿Se recolecta? | Linked | Tracking | Propósitos |
|---|---|---|---|---|
| **Purchase History** | Sí | Sí | No | App Functionality |

Es la seña de Mercado Pago (`booking_deposits`) y el historial de visitas y canjes que la
app muestra. No incluye datos de la tarjeta.

## Usage Data

| Tipo | ¿Se recolecta? | Linked | Tracking | Propósitos |
|---|---|---|---|---|
| **Product Interaction** | Sí | Sí | No | App Functionality |
| Advertising Data · Other Usage Data | No | | | |

Turnos reservados y cancelados, canjes, notificaciones leídas
(`client_notifications.read_at`), visitas.

## Diagnostics

| Tipo | ¿Se recolecta? | Linked | Tracking | Propósitos |
|---|---|---|---|---|
| **Crash Data** | Sí | **No** (not linked) | No | App Functionality |
| **Performance Data** | No | | | |
| Other Diagnostic Data | No | | | |

**Ojo con este bloque.** La app trae `firebase_crashlytics` (`pubspec.yaml`) y
`main.dart` lo prende (`setCrashlyticsCollectionEnabled(!kDebugMode)`) apenas Firebase
esté configurado de verdad. Hoy `firebase_options.dart` tiene placeholders y la
inicialización se saltea, así que **no se recolecta nada**; en cuanto el dueño corra
`flutterfire configure` empieza a recolectarse y la etiqueta tiene que estar puesta
**desde antes**. Declararlo de más no cuesta nada; declararlo de menos es una etiqueta
falsa. `PrivacyInfo.xcprivacy` no lo lista porque el SDK de Crashlytics trae su propio
manifiesto de privacidad, que Apple agrega al informe de la app.

Si el dueño decide **no** usar Crashlytics, hay que sacar la dependencia del `pubspec` y
el bloque de `main.dart`, y recién ahí quitar Crash Data de la etiqueta.

---

## Terceros que procesan estos datos (para el registro interno, no es un campo de la ficha)

| Proveedor | Qué recibe | Para qué |
|---|---|---|
| Supabase (base y auth) | todo lo anterior | Es nuestra base de datos |
| Meta / WhatsApp Cloud API | teléfono y nombre | Código de acceso, confirmación de turno, recordatorios, difusiones |
| Google Firebase (FCM + Crashlytics) | token del dispositivo, `device_id`, datos de crash | Notificaciones push y diagnóstico de fallas |
| Mercado Pago | monto y referencia del pago; los datos de la tarjeta los toma **él**, fuera de la app | Cobro de la seña |
| Vercel | tráfico de la API mobile | Hosting del backend |

Ninguno de los cinco usa los datos para publicidad propia ni para tracking cruzado: por
eso *"used to track you"* va en **No**.
