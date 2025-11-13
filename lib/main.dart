// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_options.dart';
import 'services/foreground_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('🔧 Iniciando configuración de Supabase...');
    print('📍 URL: ${SupabaseConfig.supabaseUrl}');
    print('🔑 Anon Key: ${SupabaseConfig.supabaseAnonKey.substring(0, 20)}...');

    // Inicializar Supabase (sin deep linking para evitar MissingPluginException)
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: false,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );

    // Verificar la conexión
    final supabase = Supabase.instance.client;
    print('✅ Cliente Supabase inicializado correctamente');
    print('🌐 Conectado a: ${SupabaseConfig.supabaseUrl}');

    // Prueba de conexión simple (intenta hacer un select)
    try {
      final response = await supabase
          .from(SupabaseConfig.locationsTable)
          .select('*')
          .limit(1);
      print('✅ Conexión a tabla "${SupabaseConfig.locationsTable}" exitosa');
      print('📊 Respuesta de prueba: ${response.length} registros');
    } catch (e) {
      print('⚠️ Error al probar conexión a tabla: $e');
      print('💡 Asegúrate de:');
      print(
        '   1. Crear la tabla "${SupabaseConfig.locationsTable}" en Supabase',
      );
      print('   2. Configurar las políticas RLS correctamente');
    }

    // Inicializar el servicio foreground
    ForegroundDataService.initForegroundTask();

    print('🚀 Aplicación lista para ejecutar\n');
  } catch (e, stackTrace) {
    print('❌ ERROR CRÍTICO al inicializar Supabase:');
    print('Error: $e');
    print('StackTrace: $stackTrace');
    print('\n💡 Verifica:');
    print('   1. URL correcta en supabase_options.dart');
    print('   2. Anon Key correcta (debe empezar con "eyJ...")');
    print('   3. Conexión a internet disponible');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Data Logger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
