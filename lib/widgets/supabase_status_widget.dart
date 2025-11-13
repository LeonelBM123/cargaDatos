// lib/widgets/supabase_status_widget.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_options.dart';

/// Widget de diagnóstico para verificar el estado de la conexión con Supabase
class SupabaseStatusWidget extends StatefulWidget {
  const SupabaseStatusWidget({Key? key}) : super(key: key);

  @override
  State<SupabaseStatusWidget> createState() => _SupabaseStatusWidgetState();
}

class _SupabaseStatusWidgetState extends State<SupabaseStatusWidget> {
  bool _isChecking = false;
  String _status = 'No verificado';
  Color _statusColor = Colors.grey;
  String _details = '';
  int _recordCount = 0;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    setState(() {
      _isChecking = true;
      _status = 'Verificando...';
      _statusColor = Colors.orange;
      _details = '';
    });

    try {
      final supabase = Supabase.instance.client;

      // 1. Verificar que el cliente esté inicializado
      print('🔍 Verificando cliente Supabase...');
      print('📍 URL: ${SupabaseConfig.supabaseUrl}');

      // 2. Intentar hacer una consulta simple
      print('📊 Consultando tabla "${SupabaseConfig.locationsTable}"...');
      
      final response = await supabase
          .from(SupabaseConfig.locationsTable)
          .select('*')
          .limit(5)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Timeout al conectar con Supabase'),
          );

      // 3. Verificar respuesta
      _recordCount = response.length;

      setState(() {
        _status = 'Conectado ✓';
        _statusColor = Colors.green;
        _details = 'Tabla accesible\n'
            'Registros encontrados: $_recordCount\n'
            'URL: ${SupabaseConfig.supabaseUrl}\n'
            'Tabla: ${SupabaseConfig.locationsTable}';
      });

      print('✅ Conexión a Supabase exitosa');
      print('📊 Registros en tabla: $_recordCount');
      
    } catch (e) {
      setState(() {
        _status = 'Error ✗';
        _statusColor = Colors.red;
        _details = _buildErrorMessage(e.toString());
      });

      print('❌ Error al verificar conexión: $e');
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  String _buildErrorMessage(String error) {
    if (error.contains('Timeout')) {
      return 'Error: Timeout al conectar\n\n'
          '💡 Verifica:\n'
          '• Conexión a internet\n'
          '• URL de Supabase correcta';
    } else if (error.contains('JWT') || error.contains('anon')) {
      return 'Error: Anon Key inválida\n\n'
          '💡 Verifica:\n'
          '• La Anon Key debe empezar con "eyJ..."\n'
          '• Obtén la correcta en Dashboard > Settings > API';
    } else if (error.contains('relation') || error.contains('does not exist')) {
      return 'Error: Tabla no existe\n\n'
          '💡 Crea la tabla ejecutando:\n'
          'CREATE TABLE ${SupabaseConfig.locationsTable} (\n'
          '  id bigserial PRIMARY KEY,\n'
          '  latitude double precision,\n'
          '  longitude double precision,\n'
          '  battery integer,\n'
          '  signal text,\n'
          '  timestamp text,\n'
          '  created_at timestamptz DEFAULT now()\n'
          ');';
    } else if (error.contains('permission denied') || error.contains('RLS')) {
      return 'Error: Permisos denegados (RLS)\n\n'
          '💡 Configura política RLS:\n'
          'CREATE POLICY "Allow all" ON ${SupabaseConfig.locationsTable}\n'
          '  FOR ALL USING (true);';
    } else {
      return 'Error: $error\n\n'
          '💡 Verifica la configuración en supabase_options.dart';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cloud,
                      color: _statusColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estado Supabase',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _status,
                          style: TextStyle(
                            color: _statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isChecking)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _checkConnection,
                    tooltip: 'Verificar conexión',
                  ),
              ],
            ),
            if (_details.isNotEmpty) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _details,
                  style: TextStyle(
                    fontSize: 12,
                    color: _statusColor == Colors.green
                        ? Colors.green[900]
                        : Colors.red[900],
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isChecking ? null : _testInsert,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Probar Insert'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isChecking ? null : _viewLogs,
                    icon: const Icon(Icons.article, size: 18),
                    label: const Text('Ver Logs'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testInsert() async {
    setState(() => _isChecking = true);

    try {
      final supabase = Supabase.instance.client;
      
      print('🧪 Probando inserción de datos...');
      
      final testData = {
        'latitude': -17.7833,
        'longitude': -63.1821,
        'battery': 85,
        'signal': '-45',
        'timestamp': 'Test - ${DateTime.now().toString()}',
      };

      await supabase
          .from(SupabaseConfig.locationsTable)
          .insert(testData);

      print('✅ Inserción de prueba exitosa');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Inserción de prueba exitosa'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refrescar estado
      await _checkConnection();
      
    } catch (e) {
      print('❌ Error en inserción de prueba: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
      setState(() => _isChecking = false);
    }
  }

  void _viewLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logs de Diagnóstico'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLogItem('URL', SupabaseConfig.supabaseUrl),
              _buildLogItem('Tabla', SupabaseConfig.locationsTable),
              _buildLogItem(
                'Anon Key',
                '${SupabaseConfig.supabaseAnonKey.substring(0, 30)}...',
              ),
              _buildLogItem('Estado', _status),
              _buildLogItem('Registros', _recordCount.toString()),
              const Divider(),
              const Text(
                '💡 Verifica en Supabase Dashboard:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(
                'https://supabase.com/dashboard/project/${_extractProjectId()}/editor',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _extractProjectId() {
    try {
      final uri = Uri.parse(SupabaseConfig.supabaseUrl);
      return uri.host.split('.').first;
    } catch (e) {
      return 'unknown';
    }
  }
}
