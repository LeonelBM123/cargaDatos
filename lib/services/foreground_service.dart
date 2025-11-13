// lib/services/foreground_service.dart
import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../supabase_options.dart';
import 'data_service.dart';

/// Callback que se ejecuta cuando inicia el servicio foreground
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(DataTaskHandler());
}

/// Manejador de tareas que se ejecuta en segundo plano
class DataTaskHandler extends TaskHandler {
  Timer? _timer;
  int _executionCount = 0;
  DateTime? _lastExecution;
  bool _isInitialized = false;
  int _intervalMinutes = 3; // Intervalo por defecto
  String _wifiSignal = ''; // Nivel de señal WiFi recibido del isolate principal

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('🚀 Servicio foreground iniciado: $timestamp');

    try {
      // Inicializar Supabase si no está inicializado
      if (!_isInitialized) {
        await Supabase.initialize(
          url: SupabaseConfig.supabaseUrl,
          anonKey: SupabaseConfig.supabaseAnonKey,
        );
        _isInitialized = true;
        print('✅ Supabase inicializado en servicio');
      }

      // Cargar el intervalo guardado
      final prefs = await SharedPreferences.getInstance();
      _intervalMinutes = prefs.getInt('data_interval') ?? 3;
      print('⏰ Intervalo configurado: $_intervalMinutes minutos');

      // Ejecutar inmediatamente al iniciar
      await _executeTask();

      // Programar ejecución según el intervalo configurado
      _timer = Timer.periodic(Duration(minutes: _intervalMinutes), (
        timer,
      ) async {
        await _executeTask();
      });

      print('⏰ Timer configurado para ejecutar cada $_intervalMinutes minutos');
    } catch (e) {
      print('❌ Error al iniciar servicio: $e');
    }
  }

  @override
  void onReceiveData(Object data) {
    // Recibir datos desde el isolate principal
    if (data is Map) {
      if (data.containsKey('wifi_signal')) {
        _wifiSignal = data['wifi_signal'].toString();
        print('📡 Señal WiFi recibida del isolate principal: $_wifiSignal dBm');
      }
    }
  }

  /// Ejecuta la tarea de recolección y envío de datos
  Future<void> _executeTask() async {
    _executionCount++;
    _lastExecution = DateTime.now();

    print('\n📊 ===== Ejecución #$_executionCount =====');
    print(
      '⏰ Hora: ${_lastExecution!.hour}:${_lastExecution!.minute}:${_lastExecution!.second}',
    );

    try {
      final dataService = DataService();

      // Recolectar y enviar datos, pasando el nivel de señal si está disponible
      await dataService.collectAndSendData(
        signalLevelOverride: _wifiSignal.isNotEmpty ? _wifiSignal : null,
      );

      // Obtener conteo de datos pendientes
      final pendingCount = await dataService.getPendingDataCount();

      // Actualizar notificación con información
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Data Logger Activo',
        notificationText:
            'Última actualización: ${_formatTime(_lastExecution!)} | Ejecuciones: $_executionCount',
      );

      print('✅ Ejecución #$_executionCount completada exitosamente');
      print('📝 Datos pendientes: $pendingCount');
    } catch (e) {
      print('❌ Error en ejecución #$_executionCount: $e');

      // Actualizar notificación con error
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Data Logger - Error',
        notificationText:
            'Error en última ejecución: ${_formatTime(DateTime.now())}',
      );
    }

    print('===========================\n');
  }

  /// Formatea la hora en formato HH:MM:SS
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Este método se llama periódicamente según el intervalo configurado
    // pero nosotros manejamos el tiempo con Timer, así que no lo usamos
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool stopByUser) async {
    print('🛑 Servicio foreground detenido: $timestamp');
    print('📊 Total de ejecuciones realizadas: $_executionCount');
    print('👤 Detenido por usuario: $stopByUser');

    // Cancelar el timer
    _timer?.cancel();
    _timer = null;
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('🔘 Botón de notificación presionado: $id');

    // Puedes agregar botones personalizados en la notificación
    if (id == 'sync_now') {
      // Ejecutar sincronización manual
      _executeTask();
    }
  }

  @override
  void onNotificationPressed() {
    print('👆 Notificación presionada - Abriendo app');
    // Abrir la app cuando se toca la notificación
    FlutterForegroundTask.launchApp('/');
  }
}

/// Clase de utilidad para gestionar el servicio foreground
class ForegroundDataService {
  /// Inicializar la configuración del servicio foreground
  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'data_logger_channel_v1',
        channelName: 'Data Logger Service',
        channelDescription:
            'Servicio de recolección de datos cada 3 minutos en segundo plano',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    print('✅ ForegroundTask inicializado');
  }

  /// Iniciar el servicio foreground
  static Future<bool> startService([int intervalMinutes = 3]) async {
    print(
      '🔄 Intentando iniciar servicio con intervalo de $intervalMinutes minutos...',
    );

    // Guardar el intervalo en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('data_interval', intervalMinutes);

    // Verificar si el servicio ya está corriendo
    if (await FlutterForegroundTask.isRunningService) {
      print(
        'ℹ️ El servicio ya está en ejecución - reiniciando con nuevo intervalo...',
      );
      await stopService();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    try {
      // Solicitar permisos necesarios para Android 13+
      if (!await FlutterForegroundTask.canDrawOverlays) {
        print('📱 Solicitando permiso de notificaciones...');
        final NotificationPermission notificationPermission =
            await FlutterForegroundTask.checkNotificationPermission();

        if (notificationPermission != NotificationPermission.granted) {
          await FlutterForegroundTask.requestNotificationPermission();
        }
      }

      // Solicitar ignorar optimización de batería para mejor rendimiento
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        print('🔋 Solicitando ignorar optimización de batería...');
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      print('🚀 Iniciando servicio foreground...');

      // Iniciar el servicio
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'Data Logger Iniciando',
        notificationText: 'Preparando recolección de datos...',
        callback: startCallback,
      );

      // Esperar un momento para que el servicio inicie
      await Future.delayed(const Duration(milliseconds: 500));

      // Verificar si se inició correctamente
      final bool success = await FlutterForegroundTask.isRunningService;

      if (success) {
        print('✅ Servicio foreground iniciado exitosamente');
      } else {
        print('❌ Error al iniciar servicio foreground');
      }

      return success;
    } catch (e, stackTrace) {
      print('❌ Excepción al iniciar servicio: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Detener el servicio foreground
  static Future<bool> stopService() async {
    print('🔄 Deteniendo servicio...');

    await FlutterForegroundTask.stopService();

    // Verificar si se detuvo correctamente
    final bool success = !(await FlutterForegroundTask.isRunningService);

    if (success) {
      print('✅ Servicio detenido exitosamente');
    } else {
      print('❌ Error al detener servicio');
    }

    return success;
  }

  /// Verificar si el servicio está corriendo
  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }

  /// Actualizar el texto de la notificación
  static Future<bool> updateNotification({
    required String title,
    required String text,
  }) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
    return true; // En la nueva API no hay forma directa de verificar el resultado
  }

  /// Reiniciar el servicio (útil para aplicar cambios)
  static Future<bool> restartService() async {
    print('🔄 Reiniciando servicio...');

    await stopService();
    await Future.delayed(const Duration(seconds: 1));
    return await startService();
  }
}
