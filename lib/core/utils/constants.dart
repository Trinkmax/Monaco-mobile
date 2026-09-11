/// Constantes de la app de clientes de Monaco Barber Studio.
///
/// La app es **mono-organización**: todo lo que antes era "elegí tu barbería"
/// está fijo acá. La sucursal sí la elige el cliente (Rondeau, Parana, Caseros;
/// Test sólo en modo prueba).
class AppConstants {
  AppConstants._();

  static const String appName = 'Monaco';
  static const String brandName = 'Monaco Barber Studio';

  // ── Organización (mono-org) ────────────────────────────────────────────
  static const String organizationId = String.fromEnvironment(
    'ORGANIZATION_ID',
    defaultValue: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  );
  static const String organizationSlug = String.fromEnvironment(
    'ORGANIZATION_SLUG',
    defaultValue: 'monaco',
  );

  /// Slug de la sucursal de pruebas: la app la esconde salvo "modo prueba"
  /// (7 toques sobre la versión en Perfil + [testModeCode]).
  static const String testBranchSlug = 'test';

  /// Código que se pide después de los 7 toques sobre la versión para prender
  /// el modo prueba. Existe porque la sucursal Test es una sucursal REAL de
  /// producción (toma turnos): sin código, cualquiera que descubriera el
  /// gesto —un reviewer, un cliente curioso— podía reservar ahí.
  ///
  /// No es un secreto criptográfico, es un candado de puerta: alcanza con que
  /// no sea `0000`/`1234`. Se pisa por build con
  /// `--dart-define=TEST_MODE_CODE=...`; **vacío desactiva el gesto entero**
  /// (para una build de tienda donde el modo prueba no tiene que existir).
  static const String testModeCode = String.fromEnvironment(
    'TEST_MODE_CODE',
    defaultValue: '731942',
  );

  // ── Supabase ───────────────────────────────────────────────────────────
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gzsfoqpxvnwmvngfoqqk.supabase.co',
  );
  // La anon key es pública por diseño (viaja en cualquier cliente). Lo que la
  // protege es RLS. Se puede pisar con --dart-define=SUPABASE_ANON_KEY=...
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd6c2ZvcXB4dm53bXZuZ2ZvcXFrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3NDYyOTIsImV4cCI6MjA4ODMyMjI5Mn0.fLbuqdckbBmJ4RRbLwEBAZAl4W_6cP__nElpodSVdqY',
  );

  // ── API mobile (route handlers del dashboard) ──────────────────────────
  /// Origen del dashboard Next.js que expone `/api/mobile/*` y el turnero
  /// web. Override: --dart-define=API_BASE_URL=https://...
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://monacobarber.vercel.app',
  );

  // ── Auth ───────────────────────────────────────────────────────────────
  static const int otpLength = 6;
  static const int pinLength = 4;
  static const String defaultCountryCode = '54';

  // ── Alta con Google / Apple ────────────────────────────────────────────
  //
  // **Interruptor de emergencia del login social.** Con `false` la pantalla de
  // entrada esconde Google Y Apple y queda sólo el teléfono. Es para el día en
  // que el backend no pueda validar los tokens (falta `APPLE_BUNDLE_IDS` o
  // `GOOGLE_CLIENT_IDS` en `client-auth`, o el JWKS del proveedor no baja) y
  // haya que sacar una build sin un botón que siempre falla —que es rechazo
  // 2.1 en App Review—. **La app NO intenta detectar la configuración del
  // backend**: se decide en el build, con
  //
  //   flutter build ipa --release --dart-define=SOCIAL_LOGIN_ENABLED=false
  //
  // Ojo con la 4.8: si Google está visible, Apple TIENE que estar visible y
  // funcionar. Este interruptor apaga los dos juntos justamente para no dejar
  // uno solo a medias.
  static const bool socialLoginEnabled = bool.fromEnvironment(
    'SOCIAL_LOGIN_ENABLED',
    defaultValue: true,
  );

  // **PENDIENTE DE CONFIGURACIÓN.** Los tres valores de abajo salen de la
  // consola de Google Cloud (el mismo proyecto que Firebase, pero son clientes
  // OAuth distintos del `google-services.json`) y hay que cargarlos ANTES de
  // publicar. Mientras estén vacíos, `SocialAuthService.googleConfigurado` da
  // `false` y la pantalla de entrada esconde el botón de Google en vez de
  // ofrecer algo que va a fallar.
  //
  // Se pasan por `--dart-define` para no meter identificadores de la consola en
  // el repo, y para poder tener build de prueba y de producción con clientes
  // distintos:
  //
  //   flutter build ipa --release \
  //     --dart-define=GOOGLE_IOS_CLIENT_ID=<...>.apps.googleusercontent.com \
  //     --dart-define=GOOGLE_SERVER_CLIENT_ID=<...>.apps.googleusercontent.com
  //
  // Los MISMOS ids (iOS + Android + Web/server) tienen que estar en el secret
  // `GOOGLE_CLIENT_IDS` de la edge function `client-auth`: es la lista cerrada
  // de `aud` que acepta. Si el id de acá no está allá, el login devuelve
  // `SOCIAL_TOKEN_INVALID` sin más explicación.

  /// Client OAuth **de tipo iOS**. `google_sign_in` en iOS lo lee del
  /// `GoogleService-Info.plist` si existe, pero acá se pasa explícito porque
  /// Firebase todavía no está configurado y porque el valor explícito gana.
  /// Necesita además el `CFBundleURLTypes` con el REVERSED_CLIENT_ID en
  /// `ios/Runner/Info.plist` (ver el bloque marcado ahí).
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  /// Client OAuth **de tipo Web** (el "serverClientId"). Es el que hace que el
  /// `id_token` de Android traiga nuestro `aud` en vez del de la app. En
  /// Android sin esto el token no lo podemos validar del lado del server.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  // ── Timeouts ───────────────────────────────────────────────────────────
  static const Duration apiTimeout = Duration(seconds: 15);

  /// Timeout de los endpoints de SEÑA. Es más largo que el general a
  /// propósito: crear la intención implica que nuestro server hable con
  /// Mercado Pago (preferencia de checkout) y esa llamada sale de nuestra red.
  ///
  /// Con 15 s, un pico de latencia de MP le deja al cliente la peor pantalla
  /// posible: "no pudimos" sobre una operación que quizá sí se creó. Preferimos
  /// que espere unos segundos más y reciba una respuesta cierta.
  static const Duration senaTimeout = Duration(seconds: 45);

  // ── Deep link de vuelta del checkout ───────────────────────────────────
  /// `monaco://pago?deposit=<uuid>`. Mercado Pago sólo acepta `back_urls`
  /// https, así que el retorno es MP → `\$apiBaseUrl/pago/<id>` → esta URL.
  ///
  /// **El parámetro no debería llamarse `code`**: `supabase_flutter`, con su
  /// observer de deep links prendido, trata cualquiera que traiga `code` como
  /// callback de OAuth (intenta canjearlo por sesión y falla). Ese observer
  /// está **apagado** desde el 10/sep/2026 (`detectSessionInUri: false` en
  /// `main.dart`: la app no usa OAuth de Supabase por deep link, el login
  /// social va por `client-auth` con el `id_token`), así que hoy es una
  /// defensa más y no la única.
  static const String deepLinkScheme = 'monaco';
  static const String deepLinkPagoHost = 'pago';
  static const String deepLinkPagoParam = 'deposit';

  // ── Legal y soporte ────────────────────────────────────────────────────
  //
  // **Estas cuatro URL las declaran las fichas de tienda**, así que no son
  // links decorativos del Perfil: `supportUrl` es el *Support URL* de App
  // Store Connect (campo obligatorio), `privacyPolicyUrl` es el *Privacy
  // Policy URL* que piden las dos tiendas, `deleteAccountUrl` es el recurso de
  // borrado de cuenta que Play exige declarar en Data safety —y que Apple
  // acepta como la vía "desde la web" de la 5.1.1(v)— y `arrepentimientoUrl`
  // es el botón que manda la Disp. 954/2025.
  //
  // **Las cuatro tienen que contestar 200 antes de enviar la app**: una ficha
  // con un Support URL que da 404 es rechazo en App Review (2.1) y una URL de
  // borrado caída es motivo de baja de la ficha en Play.
  // `scripts/preflight-tiendas.sh` las verifica.
  static const String privacyPolicyUrl = '$apiBaseUrl/privacidad';
  static const String termsOfServiceUrl = '$apiBaseUrl/terminos';
  static const String supportUrl = '$apiBaseUrl/soporte';
  static const String deleteAccountUrl = '$apiBaseUrl/eliminar-cuenta';
  static const String arrepentimientoUrl = '$apiBaseUrl/arrepentimiento';
  static const String supportEmail = 'studios.sys.work@gmail.com';

  /// WhatsApp de atención de Monaco: +54 9 3517 69-1830 (confirmado por el
  /// dueño el 22/ago/2026). Para `wa.me` un móvil argentino va SIEMPRE con el
  /// `9` después del 54 — sin él, WhatsApp abre un chat con un número que no
  /// existe.
  static const String supportPhoneDisplay = '+54 9 3517 69-1830';
  static const String supportWhatsappUrl = 'https://wa.me/5493517691830';
  static const String instagramUrl =
      'https://www.instagram.com/monaco.barberia';

  // ── Push ───────────────────────────────────────────────────────────────
  static const String androidNotificationChannelId = 'monaco_default';
  static const String androidNotificationChannelName = 'Monaco';
}
