// lib/services/data_service.dart
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../supabase_options.dart';
import 'network_type_detector.dart';
import 'device_info_detector.dart';

class DataService {
  // Usar Supabase en lugar de Firestore
  final SupabaseClient _supabase = Supabase.instance.client;
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();

  // Platform channel para obtener nivel de señal WiFi
  static const platform = MethodChannel('com.example.carga_datos/wifi');

  /// Formatear fecha de manera legible
  String _formatDate(DateTime dateTime) {
    final days = [
      'Domingo',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
    ];
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    final dayName = days[dateTime.weekday % 7];
    final monthName = months[dateTime.month - 1];
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');

    return '$dayName, ${dateTime.day} de $monthName de ${dateTime.year} - $hour:$minute:$second';
  }

  /// Modelo de datos para Supabase
  Map<String, dynamic> createDataPoint({
    required double latitude,
    required double longitude,
    double? altitude,
    double? speed,
    required int batteryLevel,
    required String signalLevel,
    required DateTime timestamp,
    String? networkType,
    String? deviceName,
  }) {
    // Convertir signal de String a int (o null si está vacío)
    int? signalValue;
    if (signalLevel.isNotEmpty) {
      try {
        signalValue = int.parse(signalLevel);
      } catch (e) {
        print('⚠️ No se pudo convertir signal "$signalLevel" a int: $e');
        signalValue = null;
      }
    }

    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude, // Altitud en metros
      'speed': speed, // Velocidad en m/s
      'battery': batteryLevel, // smallint
      'signal': signalValue, // smallint - Puede ser null
      'timestamp': timestamp.toIso8601String(), // timestamp without time zone
      'network_type': networkType, // varchar - Tipo de red (2G/3G/4G/5G/WiFi)
      'device_name': deviceName, // varchar - Marca y modelo del dispositivo
      // Campos opcionales que no estamos capturando aún:
      // 'sim_operator': null,
      // 'temperature': null,
    };
  }

  /// Obtener nivel de señal basado en tipo de conexión
  Future<String> getSignalLevel() async {
    try {
      final List<ConnectivityResult> connectivityResult = await _connectivity
          .checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        // Intentar obtener el nivel de señal WiFi
        try {
          // Primero intentar con MethodChannel (funciona en isolate principal)
          int? rssi;
          try {
            rssi = await platform.invokeMethod('getWifiSignalStrength');
            print("🎯 RSSI obtenido desde MethodChannel: $rssi dBm");
            return rssi.toString();
          } on MissingPluginException catch (e) {
            // MethodChannel no disponible en este isolate (foreground service)
            print("⚠️ MethodChannel no disponible en este isolate: $e");

            // Intentar con un canal alternativo que use ServicesBinding
            try {
              // Crear un nuevo MethodChannel con un nombre diferente
              const altChannel = MethodChannel(
                'com.example.carga_datos/wifi_alt',
              );
              rssi = await altChannel
                  .invokeMethod('getWifiSignalStrength')
                  .timeout(const Duration(seconds: 2), onTimeout: () => null);
              if (rssi != null) {
                print("✅ RSSI obtenido desde canal alternativo: $rssi dBm");
                return rssi.toString();
              }
            } catch (e2) {
              print("⚠️ Canal alternativo falló: $e2");
            }

            // Si todo falla, retornar '0' para indicar sin señal
            print('⚠️ No se pudo obtener RSSI en foreground service isolate');
            return '0';
          } catch (e) {
            print('⚠️ Error inesperado al obtener RSSI: $e');
            return '0';
          }
        } catch (e) {
          print("⚠️ Error al obtener detalles de WiFi: $e");
          return '';
        }
      } else {
        // No WiFi, retornar '0' para indicar sin señal
        return '0';
      }
    } catch (e) {
      print("Error al obtener nivel de señal: $e");
      return '0';
    }
  }

  /// Verificar si hay conexión a internet
  Future<bool> hasConnection() async {
    try {
      final List<ConnectivityResult> connectivityResult = await _connectivity
          .checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      print("Error al verificar conexión: $e");
      return false;
    }
  }

  /// Guardar datos localmente cuando no hay conexión
  Future<void> saveDataLocally(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingData = prefs.getStringList('pending_data') ?? [];

      // Agregar timestamp de guardado local
      data['savedLocally'] = DateTime.now().toIso8601String();

      pendingData.add(jsonEncode(data));
      await prefs.setStringList('pending_data', pendingData);

      print(
        "✅ Datos guardados localmente. Total pendientes: ${pendingData.length}",
      );
    } catch (e) {
      print("❌ Error al guardar datos localmente: $e");
    }
  }

  /// Enviar datos pendientes a Firebase
  Future<void> sendPendingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingData = prefs.getStringList('pending_data') ?? [];

      if (pendingData.isEmpty) {
        print("ℹ️ No hay datos pendientes por enviar");
        return;
      }

      print("📤 Enviando ${pendingData.length} registros pendientes...");

      int successCount = 0;
      List<String> failedData = [];

      for (String dataStr in pendingData) {
        try {
          Map<String, dynamic> data = jsonDecode(dataStr);

          // Remover el timestamp de guardado local antes de enviar
          data.remove('savedLocally');

          // Enviar a Supabase
          await _supabase.from(SupabaseConfig.locationsTable).insert(data);
          successCount++;

          print("✅ Registro enviado: ${data['timestamp']}");
        } catch (e) {
          print("❌ Error al enviar registro: $e");
          failedData.add(dataStr);
        }
      }

      // Si hubo fallos, guardar solo los que fallaron
      if (failedData.isNotEmpty) {
        await prefs.setStringList('pending_data', failedData);
        print(
          "⚠️ $successCount de ${pendingData.length} enviados. ${failedData.length} fallaron.",
        );
      } else {
        // Limpiar todos los datos pendientes
        await prefs.setStringList('pending_data', []);
        print(
          "✅ Todos los datos pendientes fueron enviados exitosamente ($successCount registros)",
        );
      }
    } catch (e) {
      print("❌ Error crítico al enviar datos pendientes: $e");
    }
  }

  /// Función principal: Recolectar y enviar datos
  /// [signalLevelOverride] permite pasar el nivel de señal desde el isolate principal
  /// cuando se ejecuta desde un foreground service (donde MethodChannel no funciona)
  /// [networkTypeOverride] permite pasar el tipo de red desde el isolate principal
  /// [deviceNameOverride] permite pasar el nombre del dispositivo desde el isolate principal
  Future<void> collectAndSendData({
    String? signalLevelOverride,
    String? networkTypeOverride,
    String? deviceNameOverride,
  }) async {
    print("\n🔄 ========== INICIANDO RECOLECCIÓN DE DATOS ==========");

    try {
      // 1. Obtener ubicación
      print("📍 Obteniendo ubicación...");
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      print(
        "✅ Ubicación obtenida: ${position.latitude}, ${position.longitude}",
      );
      print(
        "📏 Altitud: ${position.altitude}m | Velocidad: ${position.speed}m/s",
      );

      // 2. Obtener nivel de batería
      print("🔋 Obteniendo nivel de batería...");
      int batteryLevel = await _battery.batteryLevel;
      print("✅ Batería: $batteryLevel%");

      // 3. Obtener nivel de señal
      print("📶 Obteniendo nivel de señal...");
      String signalLevel;
      if (signalLevelOverride != null) {
        // Usar el valor proporcionado desde el isolate principal
        signalLevel = signalLevelOverride;
        print("✅ Señal (desde isolate principal): $signalLevel");
      } else {
        // Intentar obtenerlo directamente (solo funciona en isolate principal)
        signalLevel = await getSignalLevel();
        print("✅ Señal: $signalLevel");
      }

      // 3.5. Obtener tipo de red
      print("📡 Obteniendo tipo de red...");
      String? networkType;
      if (networkTypeOverride != null) {
        // Usar el valor proporcionado desde el isolate principal
        networkType = networkTypeOverride;
        print("✅ Tipo de red (desde isolate principal): $networkType");
      } else {
        // Intentar obtenerlo directamente (solo funciona en isolate principal)
        try {
          final networkDetector = NetworkTypeDetector();
          networkType = await networkDetector.getNetworkType();
          print("✅ Tipo de red: $networkType");
        } catch (e) {
          print("⚠️ Error al obtener tipo de red: $e");
          networkType = null;
        }
      }

      // 3.6. Obtener nombre del dispositivo
      print("📱 Obteniendo nombre del dispositivo...");
      String? deviceName;
      if (deviceNameOverride != null) {
        // Usar el valor proporcionado desde el isolate principal
        deviceName = deviceNameOverride;
        print("✅ Dispositivo (desde isolate principal): $deviceName");
      } else {
        // Intentar obtenerlo directamente
        try {
          final deviceDetector = DeviceInfoDetector();
          deviceName = await deviceDetector.getDeviceName();
          print("✅ Dispositivo: $deviceName");
        } catch (e) {
          print("⚠️ Error al obtener nombre del dispositivo: $e");
          deviceName = null;
        }
      }

      // 4. Crear punto de datos
      Map<String, dynamic> dataPoint = createDataPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        speed: position.speed,
        batteryLevel: batteryLevel,
        signalLevel: signalLevel,
        timestamp: DateTime.now(),
        networkType: networkType,
        deviceName: deviceName,
      );

      print("📦 Datos creados: $dataPoint");

      // 5. Verificar conexión
      print("🌐 Verificando conexión...");
      bool connected = await hasConnection();
      print("🌐 Conexión: ${connected ? 'DISPONIBLE' : 'NO DISPONIBLE'}");

      if (connected) {
        print("✅ Conexión disponible - Intentando enviar a Supabase...");

        try {
          // Enviar datos actuales
          print("📤 Enviando a Supabase...");
          print("📋 JSON a enviar: ${jsonEncode(dataPoint)}");

          // Enviar a Supabase (la tabla debe existir previamente)
          await _supabase
              .from(SupabaseConfig.locationsTable)
              .insert(dataPoint)
              .timeout(
                const Duration(seconds: 15),
                onTimeout: () {
                  print(
                    "⏰ TIMEOUT: Supabase no responde después de 15 segundos",
                  );
                  print("❗ VERIFICA EN SUPABASE DASHBOARD:");
                  print("   1. Ve a https://supabase.com/dashboard");
                  print(
                    "   2. Asegúrate que la tabla '${SupabaseConfig.locationsTable}' exista",
                  );
                  print("   3. Verifica que las políticas RLS permitan INSERT");
                  throw Exception('Supabase timeout - Database no responde');
                },
              );

          print("✅✅✅ DATOS ENVIADOS EXITOSAMENTE A SUPABASE ✅✅✅");

          // Intentar enviar datos pendientes
          print("📤 Verificando datos pendientes...");
          await sendPendingData();
        } catch (e, stackTrace) {
          print("❌❌❌ ERROR AL ENVIAR A SUPABASE ❌❌❌");
          print("Error: $e");
          print("StackTrace: $stackTrace");
          // Si falla el envío, guardar localmente
          await saveDataLocally(dataPoint);
        }
      } else {
        print("⚠️ Sin conexión. Guardando datos localmente...");
        await saveDataLocally(dataPoint);
      }

      print("✅ Proceso completado");
      print("========== FIN DE RECOLECCIÓN ==========\n");
    } catch (e, stackTrace) {
      print("❌❌❌ ERROR CRÍTICO AL RECOLECTAR DATOS ❌❌❌");
      print("Error: $e");
      print("StackTrace: $stackTrace");

      // Intentar guardar con datos parciales si es posible
      try {
        Map<String, dynamic> errorData = {
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
          'latitude': 0.0,
          'longitude': 0.0,
          'battery': 0,
          'signal': 'Error',
        };
        await saveDataLocally(errorData);
      } catch (saveError) {
        print("❌ No se pudo guardar datos de error: $saveError");
      }
    }
  }

  /// Obtener conteo de datos pendientes
  Future<int> getPendingDataCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingData = prefs.getStringList('pending_data') ?? [];
      return pendingData.length;
    } catch (e) {
      print("Error al obtener conteo de pendientes: $e");
      return 0;
    }
  }

  /// Obtener todos los datos pendientes (para debug)
  Future<List<Map<String, dynamic>>> getPendingDataList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingData = prefs.getStringList('pending_data') ?? [];

      return pendingData.map((dataStr) {
        try {
          return jsonDecode(dataStr) as Map<String, dynamic>;
        } catch (e) {
          return <String, dynamic>{'error': 'Invalid data'};
        }
      }).toList();
    } catch (e) {
      print("Error al obtener lista de pendientes: $e");
      return [];
    }
  }

  /// Limpiar todos los datos pendientes (útil para testing)
  Future<void> clearPendingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pending_data', []);
      print("✅ Datos pendientes eliminados");
    } catch (e) {
      print("❌ Error al limpiar datos pendientes: $e");
    }
  }

  /// Verificar permisos de ubicación
  Future<bool> checkLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      print("Error al verificar permisos: $e");
      return false;
    }
  }

  /// Obtener la última ubicación conocida (más rápido)
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      print("Error al obtener última posición: $e");
      return null;
    }
  }
}
