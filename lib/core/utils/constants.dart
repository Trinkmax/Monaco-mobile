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
  /// (7 toques sobre la versión en Perfil).
  static const String testBranchSlug = 'test';

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
  /// **El parámetro NO puede llamarse `code`**: `supabase_flutter` engancha
  /// todos los deep links del proceso y trata cualquiera que traiga `code`
  /// como callback de OAuth (intenta canjearlo por sesión y falla).
  static const String deepLinkScheme = 'monaco';
  static const String deepLinkPagoHost = 'pago';
  static const String deepLinkPagoParam = 'deposit';

  // ── Legal y soporte ────────────────────────────────────────────────────
  static const String privacyPolicyUrl = '$apiBaseUrl/privacidad';
  static const String termsOfServiceUrl = '$apiBaseUrl/terminos';
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
