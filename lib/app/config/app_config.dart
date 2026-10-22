class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mfyfbzyfzlhrpcfxtlmu.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1meWZienlmemxocnBjZnh0bG11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI1NTQwOTcsImV4cCI6MjA5ODEzMDA5N30.RiSSzQSoGgZ4sUcBfvRQIq8XgbmDdc7QDAwkwh_h-EU',
  );

  static const String googleClientIdWeb = String.fromEnvironment(
    'GOOGLE_CLIENT_ID_WEB',
    defaultValue:
        '1043515146762-s4pm3ed9r5aqface2457jafleen4q1tg.apps.googleusercontent.com',
  );

  static const String googleClientIdIos = String.fromEnvironment(
    'GOOGLE_CLIENT_ID_IOS',
    defaultValue: '',
  );
}
