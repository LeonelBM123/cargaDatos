package com.example.carga_datos

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.carga_datos/wifi"
    private val ALT_CHANNEL = "com.example.carga_datos/wifi_alt"

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
}
