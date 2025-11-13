// lib/services/data_service.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class DataService {
  // Usar Cloud Firestore en lugar de Realtime Database
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  
  // Platform channel para obtener nivel de señal WiFi
  static const platform = MethodChannel('com.example.carga_datos/wifi');
  
  /// Formatear fecha de manera legible
  String _formatDate(DateTime dateTime) {
    final days = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
    final months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    
    final dayName = days[dateTime.weekday % 7];
    final monthName = months[dateTime.month - 1];
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    
    return '$dayName, ${dateTime.day} de $monthName de ${dateTime.year} - $hour:$minute:$second';
  }
  
  /// Modelo de datos para Firebase
  Map<String, dynamic> createDataPoint({
    required double latitude,
    required double longitude,
    required int batteryLevel,
    required String signalLevel,
    required DateTime timestamp,
  }) {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'battery': batteryLevel,
      'signal': signalLevel,
      'timestamp': _formatDate(timestamp),
    };
  }
  
  /// Obtener nivel de señal basado en tipo de conexión
  Future<String> getSignalLevel() async {
    try {
      final List<ConnectivityResult> connectivityResult = 
          await _connectivity.checkConnectivity();
      
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
              const altChannel = MethodChannel('com.example.carga_datos/wifi_alt');
              rssi = await altChannel.invokeMethod('getWifiSignalStrength').timeout(
                const Duration(seconds: 2),
                onTimeout: () => null,
              );
              if (rssi != null) {
                print("✅ RSSI obtenido desde canal alternativo: $rssi dBm");
                return rssi.toString();
              }
            } catch (e2) {
              print("⚠️ Canal alternativo falló: $e2");
            }
            
            // Si todo falla, retornar cadena vacía
            print("⚠️ No se pudo obtener RSSI en foreground service isolate");
            return '';
          } catch (e) {
            print("⚠️ Error inesperado al obtener RSSI: $e");
            return '';
          }
        } catch (e) {
          print("⚠️ Error al obtener detalles de WiFi: $e");
          return '';
        }
      } else {
        // No WiFi, retornar cadena vacía
        return '';
      }
    } catch (e) {
      print("Error al obtener nivel de señal: $e");
      return '';
    }
  }
  
  /// Verificar si hay conexión a internet
  Future<bool> hasConnection() async {
    try {
      final List<ConnectivityResult> connectivityResult = 
          await _connectivity.checkConnectivity();
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
      
      print("✅ Datos guardados localmente. Total pendientes: ${pendingData.length}");
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
          
          // Enviar a Firestore
          await _firestore.collection('locations').add(data);
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
        print("⚠️ $successCount de ${pendingData.length} enviados. ${failedData.length} fallaron.");
      } else {
        // Limpiar todos los datos pendientes
        await prefs.setStringList('pending_data', []);
        print("✅ Todos los datos pendientes fueron enviados exitosamente ($successCount registros)");
      }
      
    } catch (e) {
      print("❌ Error crítico al enviar datos pendientes: $e");
    }
  }
  
  /// Función principal: Recolectar y enviar datos
  /// [signalLevelOverride] permite pasar el nivel de señal desde el isolate principal
  /// cuando se ejecuta desde un foreground service (donde MethodChannel no funciona)
  Future<void> collectAndSendData({String? signalLevelOverride}) async {
    print("\n🔄 ========== INICIANDO RECOLECCIÓN DE DATOS ==========");
    
    try {
      // 1. Obtener ubicación
      print("📍 Obteniendo ubicación...");
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      print("✅ Ubicación obtenida: ${position.latitude}, ${position.longitude}");
      
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
      
      // 4. Crear punto de datos
      Map<String, dynamic> dataPoint = createDataPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        batteryLevel: batteryLevel,
        signalLevel: signalLevel,
        timestamp: DateTime.now(),
      );
      
      print("📦 Datos creados: $dataPoint");
      
      // 5. Verificar conexión
      print("🌐 Verificando conexión...");
      bool connected = await hasConnection();
      print("🌐 Conexión: ${connected ? 'DISPONIBLE' : 'NO DISPONIBLE'}");
      
      if (connected) {
        print("✅ Conexión disponible - Intentando enviar a Firebase...");
        
        try {
          // Enviar datos actuales
          print("📤 Enviando a Firestore...");
          
          // Enviar a Firestore (genera ID automáticamente)
          final docRef = await _firestore.collection('locations').add(dataPoint).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print("⏰ TIMEOUT: Firestore no responde después de 15 segundos");
              print("❗ VERIFICA EN FIREBASE CONSOLE:");
              print("   1. Ve a https://console.firebase.google.com/project/cargadatos-5e348/firestore");
              print("   2. Asegúrate que Cloud Firestore esté CREADO");
              print("   3. Verifica que las reglas permitan escritura");
              throw Exception('Firestore timeout - Database no responde');
            },
          );
          
          print("🔑 ID del documento: ${docRef.id}");
          print("✅✅✅ DATOS ENVIADOS EXITOSAMENTE A FIRESTORE ✅✅✅");
          
          // Intentar enviar datos pendientes
          print("📤 Verificando datos pendientes...");
          await sendPendingData();
          
        } catch (e, stackTrace) {
          print("❌❌❌ ERROR AL ENVIAR A FIREBASE ❌❌❌");
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