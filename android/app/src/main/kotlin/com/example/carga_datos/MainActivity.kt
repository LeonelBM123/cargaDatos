package com.example.carga_datos

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.telephony.TelephonyManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.carga_datos/wifi"
    private val ALT_CHANNEL = "com.example.carga_datos/wifi_alt"
    private val NETWORK_CHANNEL = "com.example.carga_datos/network"
    private val PERMISSION_REQUEST_CODE = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Registrar el plugin de señal WiFi
        flutterEngine.plugins.add(WifiSignalPlugin.getInstance())
        
        // Canal principal
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getWifiSignalStrength") {
                val signalStrength = getWifiSignalStrength()
                if (signalStrength != null) {
                    result.success(signalStrength)
                } else {
                    result.error("UNAVAILABLE", "Nivel de señal WiFi no disponible", null)
                }
            } else {
                result.notImplemented()
            }
        }
        
        // Canal alternativo (para intentar desde foreground service)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALT_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getWifiSignalStrength") {
                val signalStrength = getWifiSignalStrength()
                if (signalStrength != null) {
                    result.success(signalStrength)
                } else {
                    result.error("UNAVAILABLE", "Nivel de señal WiFi no disponible", null)
                }
            } else {
                result.notImplemented()
            }
        }
        
        // Canal para detectar tipo de red móvil
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NETWORK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMobileNetworkType" -> {
                    // Verificar si tenemos permiso
                    if (hasPhoneStatePermission()) {
                        val networkType = getMobileNetworkType()
                        result.success(networkType)
                    } else {
                        // Solicitar permiso
                        pendingResult = result
                        requestPhoneStatePermission()
                    }
                }
                "getDetailedNetworkInfo" -> {
                    val detailedInfo = getDetailedNetworkInfo()
                    result.success(detailedInfo)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    /**
     * Verifica si tenemos el permiso READ_PHONE_STATE
     */
    private fun hasPhoneStatePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    /**
     * Solicita el permiso READ_PHONE_STATE
     */
    private fun requestPhoneStatePermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_PHONE_STATE),
            PERMISSION_REQUEST_CODE
        )
    }
    
    /**
     * Callback cuando el usuario responde a la solicitud de permiso
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                // Permiso concedido, obtener tipo de red
                val networkType = getMobileNetworkType()
                pendingResult?.success(networkType)
            } else {
                // Permiso denegado, retornar "Mobile"
                pendingResult?.success("Mobile")
            }
            pendingResult = null
        }
    }

    private fun getWifiSignalStrength(): Int? {
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val wifiInfo = wifiManager.connectionInfo
            return wifiInfo.rssi // Nivel de señal en dBm
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }
    
    /**
     * Obtiene el tipo de red móvil (2G, 3G, 4G, 5G)
     * Requiere permiso READ_PHONE_STATE
     */
    private fun getMobileNetworkType(): String {
        try {
            val connectivityManager = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = connectivityManager.activeNetwork
                val capabilities = connectivityManager.getNetworkCapabilities(network)
                
                if (capabilities != null && capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
                    val telephonyManager = applicationContext.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                    
                    val networkType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        telephonyManager.dataNetworkType
                    } else {
                        @Suppress("DEPRECATION")
                        telephonyManager.networkType
                    }
                    
                    val result = when (networkType) {
                        TelephonyManager.NETWORK_TYPE_GPRS,
                        TelephonyManager.NETWORK_TYPE_EDGE,
                        TelephonyManager.NETWORK_TYPE_CDMA,
                        TelephonyManager.NETWORK_TYPE_1xRTT,
                        TelephonyManager.NETWORK_TYPE_IDEN -> "2G"
                        
                        TelephonyManager.NETWORK_TYPE_UMTS,
                        TelephonyManager.NETWORK_TYPE_EVDO_0,
                        TelephonyManager.NETWORK_TYPE_EVDO_A,
                        TelephonyManager.NETWORK_TYPE_HSDPA,
                        TelephonyManager.NETWORK_TYPE_HSUPA,
                        TelephonyManager.NETWORK_TYPE_HSPA,
                        TelephonyManager.NETWORK_TYPE_EVDO_B,
                        TelephonyManager.NETWORK_TYPE_EHRPD,
                        TelephonyManager.NETWORK_TYPE_HSPAP -> "3G"
                        
                        TelephonyManager.NETWORK_TYPE_LTE,
                        TelephonyManager.NETWORK_TYPE_IWLAN -> "4G"
                        
                        TelephonyManager.NETWORK_TYPE_NR -> "5G"
                        
                        TelephonyManager.NETWORK_TYPE_UNKNOWN -> "Mobile"
                        
                        else -> "Mobile"
                    }
                    
                    return result
                }
            } else {
                @Suppress("DEPRECATION")
                val networkInfo = connectivityManager.activeNetworkInfo
                
                if (networkInfo != null && networkInfo.type == ConnectivityManager.TYPE_MOBILE) {
                    val telephonyManager = applicationContext.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                    
                    @Suppress("DEPRECATION")
                    val networkType = telephonyManager.networkType
                    
                    return when (networkType) {
                        TelephonyManager.NETWORK_TYPE_GPRS,
                        TelephonyManager.NETWORK_TYPE_EDGE,
                        TelephonyManager.NETWORK_TYPE_CDMA,
                        TelephonyManager.NETWORK_TYPE_1xRTT,
                        TelephonyManager.NETWORK_TYPE_IDEN -> "2G"
                        
                        TelephonyManager.NETWORK_TYPE_UMTS,
                        TelephonyManager.NETWORK_TYPE_EVDO_0,
                        TelephonyManager.NETWORK_TYPE_EVDO_A,
                        TelephonyManager.NETWORK_TYPE_HSDPA,
                        TelephonyManager.NETWORK_TYPE_HSUPA,
                        TelephonyManager.NETWORK_TYPE_HSPA,
                        TelephonyManager.NETWORK_TYPE_EVDO_B,
                        TelephonyManager.NETWORK_TYPE_EHRPD,
                        TelephonyManager.NETWORK_TYPE_HSPAP -> "3G"
                        
                        TelephonyManager.NETWORK_TYPE_LTE,
                        TelephonyManager.NETWORK_TYPE_IWLAN -> "4G"
                        
                        TelephonyManager.NETWORK_TYPE_NR -> "5G"
                        
                        else -> "Mobile"
                    }
                }
            }
            
            return "Unknown"
        } catch (e: Exception) {
            return "Mobile"
        }
    }
    
    /**
     * Obtiene información detallada de la red móvil
     */
    private fun getDetailedNetworkInfo(): Map<String, Any?> {
        try {
            val telephonyManager = applicationContext.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            val networkType = getMobileNetworkType()
            
            // Obtener el tipo de red según la versión de Android
            val dataNetworkType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                telephonyManager.dataNetworkType
            } else {
                @Suppress("DEPRECATION")
                telephonyManager.networkType
            }
            
            val subtype = when (dataNetworkType) {
                TelephonyManager.NETWORK_TYPE_GPRS -> "GPRS"
                TelephonyManager.NETWORK_TYPE_EDGE -> "EDGE"
                TelephonyManager.NETWORK_TYPE_CDMA -> "CDMA"
                TelephonyManager.NETWORK_TYPE_1xRTT -> "1xRTT"
                TelephonyManager.NETWORK_TYPE_IDEN -> "IDEN"
                TelephonyManager.NETWORK_TYPE_UMTS -> "UMTS"
                TelephonyManager.NETWORK_TYPE_EVDO_0 -> "EVDO_0"
                TelephonyManager.NETWORK_TYPE_EVDO_A -> "EVDO_A"
                TelephonyManager.NETWORK_TYPE_HSDPA -> "HSDPA"
                TelephonyManager.NETWORK_TYPE_HSUPA -> "HSUPA"
                TelephonyManager.NETWORK_TYPE_HSPA -> "HSPA"
                TelephonyManager.NETWORK_TYPE_EVDO_B -> "EVDO_B"
                TelephonyManager.NETWORK_TYPE_EHRPD -> "EHRPD"
                TelephonyManager.NETWORK_TYPE_HSPAP -> "HSPA+"
                TelephonyManager.NETWORK_TYPE_LTE -> "LTE"
                TelephonyManager.NETWORK_TYPE_IWLAN -> "IWLAN"
                TelephonyManager.NETWORK_TYPE_NR -> "NR"
                else -> "Unknown"
            }
            
            val operatorName = telephonyManager.networkOperatorName ?: "Unknown"
            val isRoaming = telephonyManager.isNetworkRoaming
            
            return mapOf(
                "type" to networkType,
                "subtype" to subtype,
                "operatorName" to operatorName,
                "isRoaming" to isRoaming
            )
        } catch (e: Exception) {
            return mapOf(
                "type" to "Unknown",
                "subtype" to null,
                "operatorName" to null,
                "isRoaming" to false
            )
        }
    }
}
