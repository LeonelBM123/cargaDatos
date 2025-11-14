// lib/services/device_info_detector.dart
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// Servicio para detectar información del dispositivo
class DeviceInfoDetector {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Obtener el nombre del dispositivo
  /// Retorna el modelo y marca del dispositivo
  Future<String> getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Combinar marca y modelo (ej: "Xiaomi Redmi Note 10")
        final brand = androidInfo.brand.toUpperCase();
        final model = androidInfo.model;
        return '$brand $model';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.name;
      }
      return 'Unknown';
    } catch (e) {
      print('❌ ERROR en getDeviceName: $e');
      return 'Unknown';
    }
  }

  /// Obtener solo la marca del dispositivo
  Future<String> getDeviceBrand() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.brand.toUpperCase();
      } else if (Platform.isIOS) {
        return 'APPLE';
      }
      return 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  /// Obtener solo el modelo del dispositivo
  Future<String> getDeviceModel() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.model;
      }
      return 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  /// Obtener información completa del dispositivo
  Future<Map<String, String>> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'brand': androidInfo.brand.toUpperCase(),
          'model': androidInfo.model,
          'device': androidInfo.device,
          'manufacturer': androidInfo.manufacturer.toUpperCase(),
          'androidVersion': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt.toString(),
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'brand': 'APPLE',
          'model': iosInfo.model,
          'device': iosInfo.name,
          'manufacturer': 'APPLE',
          'iosVersion': iosInfo.systemVersion,
          'sdkInt': '',
        };
      }
      return {
        'brand': 'Unknown',
        'model': 'Unknown',
        'device': 'Unknown',
        'manufacturer': 'Unknown',
        'androidVersion': '',
        'sdkInt': '',
      };
    } catch (_) {
      return {
        'brand': 'Unknown',
        'model': 'Unknown',
        'device': 'Unknown',
        'manufacturer': 'Unknown',
        'androidVersion': '',
        'sdkInt': '',
      };
    }
  }
}
