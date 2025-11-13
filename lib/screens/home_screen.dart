// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/foreground_service.dart';
import '../services/data_service.dart';
import '../services/wifi_signal_monitor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DataService _dataService = DataService();
  
  bool _isServiceRunning = false;
  bool _isLoading = false;
  int _pendingDataCount = 0;
  int _executionCount = 0;
  int _selectedInterval = 3; // Intervalo por defecto: 3 minutos
  
  String _latitude = "---";
  String _longitude = "---";
  String _battery = "---";
  String _signal = "---";
  String _lastUpdate = "---";
  
  // Opciones de intervalo en minutos
  final List<int> _intervalOptions = [1, 3, 5, 10, 15, 30];
  
  @override
  void initState() {
    super.initState();
    _loadPendingDataCount();
    _checkServiceStatus();
    _loadSavedInterval();
  }
  
  Future<void> _loadSavedInterval() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedInterval = prefs.getInt('data_interval') ?? 3;
    });
  }
  
  Future<void> _saveInterval(int interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('data_interval', interval);
    setState(() {
      _selectedInterval = interval;
    });
  }
  
  Future<void> _checkServiceStatus() async {
    final isRunning = await ForegroundDataService.isRunning();
    setState(() {
      _isServiceRunning = isRunning;
    });
  }
  
  Future<void> _loadPendingDataCount() async {
    final count = await _dataService.getPendingDataCount();
    setState(() {
      _pendingDataCount = count;
    });
  }
  
  Future<void> _updateCurrentData() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      Battery battery = Battery();
      int batteryLevel = await battery.batteryLevel;
      String signal = await _dataService.getSignalLevel();
      
      setState(() {
        _latitude = position.latitude.toStringAsFixed(6);
        _longitude = position.longitude.toStringAsFixed(6);
        _battery = "$batteryLevel%";
        _signal = signal;
      });
    } catch (e) {
      _showSnackBar("Error al obtener datos: $e", isError: true);
    }
  }
  
  Future<void> _startService() async {
    setState(() => _isLoading = true);
    
    // Solicitar permisos de ubicación
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever || 
        permission == LocationPermission.denied) {
      _showSnackBar("Permisos de ubicación denegados", isError: true);
      setState(() => _isLoading = false);
      return;
    }
    
    // Guardar el intervalo antes de iniciar
    await _saveInterval(_selectedInterval);
    
    // Iniciar el monitoreo de señal WiFi
    WifiSignalMonitor.startMonitoring();
    
    // Iniciar servicio foreground con el intervalo seleccionado
    bool success = await ForegroundDataService.startService(_selectedInterval);
    
    setState(() {
      _isServiceRunning = success;
      _isLoading = false;
    });
    
    if (success) {
      _showSnackBar("Servicio iniciado - ejecutándose cada $_selectedInterval minutos");
      await _updateCurrentData();
    } else {
      _showSnackBar("Error al iniciar servicio", isError: true);
    }
  }
  
  Future<void> _stopService() async {
    setState(() => _isLoading = true);
    
    // Detener el monitoreo de señal WiFi
    WifiSignalMonitor.stopMonitoring();
    
    bool success = await ForegroundDataService.stopService();
    
    setState(() {
      _isServiceRunning = !success;
      _isLoading = false;
    });
    
    _showSnackBar("Servicio detenido");
  }
  
  Future<void> _sendManually() async {
    setState(() => _isLoading = true);
    
    try {
      await _dataService.collectAndSendData();
      await _loadPendingDataCount();
      await _updateCurrentData();
      _showSnackBar("Datos enviados correctamente");
    } catch (e) {
      _showSnackBar("Error al enviar datos: $e", isError: true);
    }
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _syncPendingData() async {
    if (_pendingDataCount == 0) {
      _showSnackBar("No hay datos pendientes por sincronizar");
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await _dataService.sendPendingData();
      await _loadPendingDataCount();
      _showSnackBar("$_pendingDataCount datos sincronizados");
    } catch (e) {
      _showSnackBar("Error al sincronizar: $e", isError: true);
    }
    
    setState(() => _isLoading = false);
  }
  
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  Widget _buildDataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Data Logger (${_selectedInterval} min)'),
          centerTitle: true,
          elevation: 2,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await _updateCurrentData();
                  await _loadPendingDataCount();
                  await _checkServiceStatus();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Selector de intervalo
                      if (!_isServiceRunning) ...[
                        Card(
                          elevation: 4,
                          color: Colors.blue[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.timer, color: Colors.blue[700]),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Intervalo de Envío',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _intervalOptions.map((interval) {
                                    final isSelected = interval == _selectedInterval;
                                    return ChoiceChip(
                                      label: Text('$interval min'),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _selectedInterval = interval;
                                          });
                                        }
                                      },
                                      selectedColor: Colors.blue[700],
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black87,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Los datos se enviarán cada $_selectedInterval minutos',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Estado del servicio
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(
                                _isServiceRunning ? Icons.cloud_done : Icons.cloud_off,
                                size: 48,
                                color: _isServiceRunning ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isServiceRunning ? 'Servicio Activo' : 'Servicio Inactivo',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (_isServiceRunning) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Frecuencia: cada $_selectedInterval minutos',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                Text(
                                  'Ejecuciones: $_executionCount',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isServiceRunning ? _stopService : _startService,
                                  icon: Icon(_isServiceRunning ? Icons.stop : Icons.play_arrow),
                                  label: Text(_isServiceRunning ? 'Detener Servicio' : 'Iniciar Servicio'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isServiceRunning ? Colors.red : Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Datos actuales
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Datos Actuales',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Divider(),
                              _buildDataRow(Icons.location_on, 'Latitud', _latitude),
                              _buildDataRow(Icons.my_location, 'Longitud', _longitude),
                              _buildDataRow(Icons.battery_full, 'Batería', _battery),
                              _buildDataRow(Icons.signal_cellular_alt, 'Señal', _signal),
                              _buildDataRow(Icons.access_time, 'Última actualización', _lastUpdate),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Datos pendientes y acciones
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Datos Pendientes',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Chip(
                                    label: Text('$_pendingDataCount'),
                                    backgroundColor: _pendingDataCount > 0 ? Colors.orange : Colors.green,
                                    labelStyle: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _sendManually,
                                  icon: const Icon(Icons.send),
                                  label: const Text('Enviar Ahora'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _syncPendingData,
                                  icon: const Icon(Icons.sync),
                                  label: const Text('Sincronizar Pendientes'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Información
                      Card(
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Información',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: Colors.blue[900],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• El servicio envía datos cada 3 minutos\n'
                                '• Los datos se guardan localmente si no hay conexión\n'
                                '• Se sincronizan automáticamente al recuperar conexión\n'
                                '• Desliza hacia abajo para refrescar',
                                style: TextStyle(color: Colors.blue[900], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
  
  @override
  void dispose() {
    FlutterForegroundTask.clearAllData();
    super.dispose();
  }
}