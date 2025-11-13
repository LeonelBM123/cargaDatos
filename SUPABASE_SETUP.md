# 🚀 Configuración de Supabase para Data Logger

## 📋 Paso 1: Crear la tabla `locations`

Ve a tu proyecto en Supabase Dashboard y ejecuta este SQL:

```sql
-- Crear o modificar tabla locations
CREATE TABLE IF NOT EXISTS locations (
  id bigserial PRIMARY KEY,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  battery integer NOT NULL,
  signal integer,  -- Puede ser NULL cuando no hay señal WiFi
  timestamp timestamptz NOT NULL,  -- Fecha/hora en formato ISO 8601
  timestamp_formatted text,  -- Fecha legible (opcional)
  created_at timestamptz DEFAULT now()
);

-- Si la tabla ya existe, actualiza el tipo de columna
ALTER TABLE locations 
  ALTER COLUMN timestamp TYPE timestamptz USING timestamp::timestamptz;

-- Agregar columna timestamp_formatted si no existe
ALTER TABLE locations 
  ADD COLUMN IF NOT EXISTS timestamp_formatted text;

-- Crear índice para mejorar consultas por fecha
CREATE INDEX IF NOT EXISTS idx_locations_timestamp ON locations(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_locations_created_at ON locations(created_at DESC);

-- Opcional: Agregar comentarios descriptivos
COMMENT ON TABLE locations IS 'Tabla para almacenar datos de ubicación, batería y señal WiFi';
COMMENT ON COLUMN locations.signal IS 'Nivel de señal WiFi en dBm (ej: -45). NULL si no hay WiFi';
COMMENT ON COLUMN locations.timestamp IS 'Fecha/hora del registro en formato ISO 8601';
COMMENT ON COLUMN locations.timestamp_formatted IS 'Fecha legible para humanos';
```

## 🔓 Paso 2: Configurar políticas RLS (Row Level Security)

```sql
-- Habilitar RLS
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;

-- Crear política para permitir INSERT a todos
CREATE POLICY "Allow insert for all" ON locations
  FOR INSERT 
  WITH CHECK (true);

-- Crear política para permitir SELECT a todos
CREATE POLICY "Allow select for all" ON locations
  FOR SELECT 
  USING (true);

-- Opcional: Permitir UPDATE y DELETE (solo si lo necesitas)
CREATE POLICY "Allow update for all" ON locations
  FOR UPDATE 
  USING (true);

CREATE POLICY "Allow delete for all" ON locations
  FOR DELETE 
  USING (true);
```

## 🔑 Paso 3: Obtener credenciales correctas

1. Ve a **Settings** > **API**
2. Copia:
   - **Project URL**: `https://lmqpbtuljodwklxdixjq.supabase.co`
   - **anon/public key**: Debe empezar con `eyJ...` (NO `sb_publishable_...`)

3. Pega las credenciales en `lib/supabase_options.dart`:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://lmqpbtuljodwklxdixjq.supabase.co';
  static const String supabaseAnonKey = 'eyJ...'; // ← Pega aquí la clave correcta
  static const String locationsTable = 'locations';
}
```

## ✅ Paso 4: Verificar

Ejecuta este SQL para verificar que la tabla existe:

```sql
SELECT 
  column_name, 
  data_type, 
  is_nullable
FROM information_schema.columns
WHERE table_name = 'locations'
ORDER BY ordinal_position;
```

Deberías ver:

| column_name          | data_type                | is_nullable |
|----------------------|--------------------------|-------------|
| id                   | bigint                   | NO          |
| latitude             | double precision         | NO          |
| longitude            | double precision         | NO          |
| battery              | integer                  | NO          |
| signal               | integer                  | YES         |
| timestamp            | timestamp with time zone | NO          |
| timestamp_formatted  | text                     | YES         |
| created_at           | timestamp with time zone | YES         |

## 📊 Consultas útiles

### Ver últimos 10 registros:
```sql
SELECT * FROM locations 
ORDER BY created_at DESC 
LIMIT 10;
```

### Contar registros totales:
```sql
SELECT COUNT(*) as total FROM locations;
```

### Ver registros sin señal WiFi:
```sql
SELECT * FROM locations 
WHERE signal IS NULL 
ORDER BY created_at DESC;
```

### Eliminar todos los datos (cuidado!):
```sql
TRUNCATE TABLE locations RESTART IDENTITY;
```

## 🐛 Solución de problemas comunes

### Error: "invalid input syntax for type smallint"
- **Causa**: El campo `signal` está definido como `smallint` en lugar de `integer`
- **Solución**: Ejecuta:
  ```sql
  ALTER TABLE locations ALTER COLUMN signal TYPE integer;
  ```

### Error: "permission denied" o "RLS"
- **Causa**: Las políticas RLS no están configuradas
- **Solución**: Ejecuta las políticas del Paso 2

### Error: "relation does not exist"
- **Causa**: La tabla no existe
- **Solución**: Ejecuta el SQL del Paso 1

## 📱 Estructura de datos enviados

Cada registro insertado tiene esta estructura:

```json
{
  "latitude": -17.7833,
  "longitude": -63.1821,
  "battery": 85,
  "signal": -45,  // o null si no hay WiFi
  "timestamp": "2025-11-13T22:24:04.000Z",  // ISO 8601
  "timestamp_formatted": "Jueves, 13 de Noviembre de 2025 - 22:24:04"
}
```
