package com.example.carga_datos

import android.content.Context
import android.net.wifi.WifiManager

object WifiSignalHelper {
    /**
     * Obtiene el nivel de señal WiFi en dBm
     * Este método puede ser llamado desde cualquier isolate
     */
    fun getWifiSignalStrength(context: Context): Int? {
        return try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val wifiInfo = wifiManager.connectionInfo
            wifiInfo.rssi // Retorna el nivel de señal en dBm
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
