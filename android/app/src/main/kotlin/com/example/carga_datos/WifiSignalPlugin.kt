package com.example.carga_datos

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class WifiSignalPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null

    companion object {
        private var instance: WifiSignalPlugin? = null
        
        fun getInstance(): WifiSignalPlugin {
            if (instance == null) {
                instance = WifiSignalPlugin()
            }
            return instance!!
        }
        
        // Método estático que puede ser llamado directamente
        fun getSignalStrength(context: Context): Int? {
            return WifiSignalHelper.getWifiSignalStrength(context)
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.example.carga_datos/wifi")
        channel.setMethodCallHandler(this)
        instance = this
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "getWifiSignalStrength") {
            val context = applicationContext
            if (context != null) {
                val signalStrength = WifiSignalHelper.getWifiSignalStrength(context)
                if (signalStrength != null) {
                    result.success(signalStrength)
                } else {
                    result.error("UNAVAILABLE", "Nivel de señal WiFi no disponible", null)
                }
            } else {
                result.error("NO_CONTEXT", "Application context not available", null)
            }
        } else {
            result.notImplemented()
        }
    }
    
    fun getContext(): Context? {
        return applicationContext
    }
}
