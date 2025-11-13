// lib/supabase_options.dart
/// Configuración de Supabase para la aplicación
///
/// IMPORTANTE: Reemplaza estos valores con tus credenciales de Supabase:
/// 1. Ve a https://supabase.com/dashboard
/// 2. Selecciona tu proyecto
/// 3. Ve a Settings > API
/// 4. Copia la URL y la anon/public key
class SupabaseConfig {
  // URL de tu proyecto Supabase (ejemplo: https://xxxxx.supabase.co)
  static const String supabaseUrl = 'https://lmqpbtuljodwklxdixjq.supabase.co';

  // Anon key (clave pública) de tu proyecto Supabase
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxtcXBidHVsam9kd2tseGRpeGpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNDc3MDcsImV4cCI6MjA3ODYyMzcwN30.Y5dmY4yclO-abjPMWV_V-jctXzg9fmoMG0ecM6MqWoo';

  // Nombre de la tabla donde se guardarán los datos
  static const String locationsTable = 'locations';
}
