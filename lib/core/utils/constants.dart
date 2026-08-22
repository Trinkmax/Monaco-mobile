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
    defaultValue: 'https://monaco-smart-barber.vercel.app',
  );

  // ── Auth ───────────────────────────────────────────────────────────────
  static const int otpLength = 6;
  static const int pinLength = 4;
  static const String defaultCountryCode = '54';

  // ── Timeouts ───────────────────────────────────────────────────────────
  static const Duration apiTimeout = Duration(seconds: 15);

  // ── Legal y soporte ────────────────────────────────────────────────────
  static const String privacyPolicyUrl = '$apiBaseUrl/privacidad';
  static const String termsOfServiceUrl = '$apiBaseUrl/terminos';
  static const String supportEmail = 'studios.sys.work@gmail.com';

  /// WhatsApp de atención de Monaco (el mismo que publica el sitio
  /// monaco-barber-studio). Se arma como link `wa.me`.
  static const String supportWhatsappUrl = 'https://wa.me/543517691830';
  static const String instagramUrl = 'https://www.instagram.com/monaco.barberia';

  // ── Push ───────────────────────────────────────────────────────────────
  static const String androidNotificationChannelId = 'monaco_default';
  static const String androidNotificationChannelName = 'Monaco';
}
