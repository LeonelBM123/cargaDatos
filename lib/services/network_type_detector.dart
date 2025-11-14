// lib/services/network_type_detector.dart
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Servicio para detectar el tipo de red móvil (2G, 3G, 4G, 5G)
///
/// Este servicio utiliza Platform Channels para acceder a las APIs nativas
/// de Android y obtener información detallada del tipo de conexión de red móvil.
class NetworkTypeDetector {
  static const platform = MethodChannel('com.example.carga_datos/network');
  final Connectivity _connectivity = Connectivity();

  /// Obtener el tipo de red actual
  ///
  /// Retorna:
  /// - "WiFi" si está conectado a WiFi
  /// - "2G", "3G", "4G", "5G" si está usando datos móviles
  /// - "Unknown" si no se puede determinar
  /// - "None" si no hay conexión
  Future<String> getNetworkType() async {
    try {
      // 1. Verificar el tipo de conectividad básica
      final List<ConnectivityResult> connectivityResult = await _connectivity
          .checkConnectivity();

      // 2. Si está en WiFi, retornar WiFi
      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        return 'WiFi';
      }

      // 3. Si está en Ethernet, retornar Ethernet
      if (connectivityResult.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      }

      // 4. Si está usando datos móviles, obtener el tipo específico
      if (connectivityResult.contains(ConnectivityResult.mobile)) {
        try {
          // Llamar al método nativo para obtener el tipo de red móvil
          final String? mobileNetworkType = await platform.invokeMethod(
            'getMobileNetworkType',
          );

          if (mobileNetworkType != null &&
              mobileNetworkType.isNotEmpty &&
              mobileNetworkType != 'Unknown') {
            return mobileNetworkType;
          } else {
            return mobileNetworkType ?? 'Mobile';
          }
        } on MissingPluginException catch (_) {
          return 'Mobile';
        } on PlatformException catch (_) {
          return 'Mobile';
        } catch (_) {
          return 'Mobile';
        }
      }

      // 5. Sin conexión
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return 'None';
      }

      // 6. Tipo desconocido
      return 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  /// Obtener información detallada de la red
  ///
  /// Retorna un mapa con información adicional como:
  /// - type: tipo de red (WiFi, 2G, 3G, 4G, 5G)
  /// - subtype: subtipo específico (GPRS, EDGE, UMTS, LTE, etc.)
  /// - isRoaming: si está en roaming
  /// - operatorName: nombre del operador móvil
  Future<Map<String, dynamic>> getDetailedNetworkInfo() async {
    try {
      final networkType = await getNetworkType();

      // Si no es datos móviles, retornar información básica
      if (networkType != 'Mobile' &&
          !['2G', '3G', '4G', '5G'].contains(networkType)) {
        return {
          'type': networkType,
          'subtype': null,
          'isRoaming': false,
          'operatorName': null,
        };
      }

      // Obtener información detallada de la red móvil
      try {
        final Map<dynamic, dynamic>? detailedInfo = await platform.invokeMethod(
          'getDetailedNetworkInfo',
        );

        if (detailedInfo != null) {
          return {
            'type': detailedInfo['type'] ?? networkType,
            'subtype': detailedInfo['subtype'],
            'isRoaming': detailedInfo['isRoaming'] ?? false,
            'operatorName': detailedInfo['operatorName'],
          };
        }
      } catch (_) {
        // Ignorar errores
      }

      // Si falla, retornar información básica
      return {
        'type': networkType,
        'subtype': null,
        'isRoaming': false,
        'operatorName': null,
      };
    } catch (_) {
      return {
        'type': 'Unknown',
        'subtype': null,
        'isRoaming': false,
        'operatorName': null,
      };
    }
  }

  /// Verificar si está usando datos móviles
  Future<bool> isUsingMobileData() async {
    final networkType = await getNetworkType();
    return ['2G', '3G', '4G', '5G', 'Mobile'].contains(networkType);
  }

  /// Verificar si está conectado a WiFi
  Future<bool> isUsingWiFi() async {
    final networkType = await getNetworkType();
    return networkType == 'WiFi';
  }

  /// Obtener una descripción amigable del tipo de red
  Future<String> getNetworkDescription() async {
    final networkType = await getNetworkType();

    switch (networkType) {
      case '2G':
        return 'Red Móvil 2G (GPRS/EDGE)';
      case '3G':
        return 'Red Móvil 3G (UMTS/HSPA)';
      case '4G':
        return 'Red Móvil 4G (LTE)';
      case '5G':
        return 'Red Móvil 5G';
      case 'WiFi':
        return 'Red WiFi';
      case 'Ethernet':
        return 'Red Ethernet';
      case 'Mobile':
        return 'Red Móvil (tipo desconocido)';
      case 'None':
        return 'Sin conexión';
      default:
        return 'Red desconocida';
    }
  }
}
