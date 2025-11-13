// lib/services/wifi_signal_monitor.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class WifiSignalMonitor {
  static const platform = MethodChannel('com.example.carga_datos/wifi');
  static Timer? _timer;
  static String _lastSignalLevel = '';

  /// Iniciar el monitoreo del nivel de señal WiFi
  /// y enviar actualizaciones al foreground service
  static void startMonitoring() {
    print("📡 Iniciando monitoreo de señal WiFi...");
    
    // Detener timer anterior si existe
    _timer?.cancel();
    
    // Actualizar cada 10 segundos
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final rssi = await platform.invokeMethod('getWifiSignalStrength');
        if (rssi != null) {
          _lastSignalLevel = rssi.toString();
          print("📡 Señal WiFi actualizada: $_lastSignalLevel dBm");
          
          // Enviar al foreground service
          FlutterForegroundTask.sendDataToTask({'wifi_signal': _lastSignalLevel});
        }
      } catch (e) {
        print("⚠️ Error al obtener señal WiFi: $e");
        _lastSignalLevel = '';
      }
    });
    
    // También obtener inmediatamente
    _updateSignalLevel();
  }

  /// Detener el monitoreo
  static void stopMonitoring() {
    print("📡 Deteniendo monitoreo de señal WiFi...");
    _timer?.cancel();
    _timer = null;
  }

  /// Obtener el último nivel de señal conocido
  static String getLastSignalLevel() {
    return _lastSignalLevel;
  }

  /// Actualizar el nivel de señal inmediatamente
  static Future<void> _updateSignalLevel() async {
    try {
      final rssi = await platform.invokeMethod('getWifiSignalStrength');
      if (rssi != null) {
        _lastSignalLevel = rssi.toString();
        print("📡 Señal WiFi obtenida: $_lastSignalLevel dBm");
        
        // Enviar al foreground service
        FlutterForegroundTask.sendDataToTask({'wifi_signal': _lastSignalLevel});
      }
    } catch (e) {
      print("⚠️ Error al obtener señal WiFi inicial: $e");
      _lastSignalLevel = '';
    }
  }
}
