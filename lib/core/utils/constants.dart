class AppConstants {
  AppConstants._();

  static const String appName = 'Monaco Smart Barber';
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gzsfoqpxvnwmvngfoqqk.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd6c2ZvcXB4dm53bXZuZ2ZvcXFrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3NDYyOTIsImV4cCI6MjA4ODMyMjI5Mn0.fLbuqdckbBmJ4RRbLwEBAZAl4W_6cP__nElpodSVdqY',
  );

  // Auth
  static const int pinMinLength = 4;
  static const int pinMaxLength = 6;
  static const int deviceSecretLength = 64;

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 15);
  static const Duration realtimeReconnect = Duration(seconds: 5);

  // Pagination
  static const int defaultPageSize = 20;

  // Cache
  static const Duration cacheDuration = Duration(minutes: 5);

  // URLs legales (actualizar con los dominios definitivos antes de release)
  static const String privacyPolicyUrl = 'https://barberos.app/privacy';
  static const String termsOfServiceUrl = 'https://barberos.app/terms';
  static const String supportEmail = 'soporte@barberos.app';
  static const String supportWhatsapp = 'https://wa.me/5491100000000';
}
