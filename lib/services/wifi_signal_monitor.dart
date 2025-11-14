// lib/services/wifi_signal_monitor.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'network_type_detector.dart';

class WifiSignalMonitor {
  static const platform = MethodChannel('com.example.carga_datos/wifi');
  static final _networkDetector = NetworkTypeDetector();
  static Timer? _timer;
  static String _lastSignalLevel = '';
  static String _lastNetworkType = '';

  /// Iniciar el monitoreo del nivel de señal WiFi
  /// y enviar actualizaciones al foreground service
  static void startMonitoring() {
    // Detener timer anterior si existe
    _timer?.cancel();

    // Actualizar cada 10 segundos
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        // Obtener señal WiFi
        final rssi = await platform.invokeMethod('getWifiSignalStrength');
        if (rssi != null) {
          _lastSignalLevel = rssi.toString();
        }

        // Obtener tipo de red
        try {
          final networkType = await _networkDetector.getNetworkType();
          _lastNetworkType = networkType;
        } catch (e) {
          // Ignorar error
        }

        // Enviar ambos datos al foreground service
        FlutterForegroundTask.sendDataToTask({
          'wifi_signal': _lastSignalLevel,
          'network_type': _lastNetworkType,
        });
      } catch (e) {
        _lastSignalLevel = '';
      }
    });

    // También obtener inmediatamente
    _updateSignalLevel();
  }

  /// Detener el monitoreo
  static void stopMonitoring() {
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
      // Obtener señal WiFi
      final rssi = await platform.invokeMethod('getWifiSignalStrength');
      if (rssi != null) {
        _lastSignalLevel = rssi.toString();
      }

      // Obtener tipo de red
      try {
        final networkType = await _networkDetector.getNetworkType();
        _lastNetworkType = networkType;
      } catch (e) {
        // Ignorar error
      }

      // Enviar ambos datos al foreground service
      FlutterForegroundTask.sendDataToTask({
        'wifi_signal': _lastSignalLevel,
        'network_type': _lastNetworkType,
      });
    } catch (e) {
      _lastSignalLevel = '';
    }
  }
}
