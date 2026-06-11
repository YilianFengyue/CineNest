package com.example.cine_nest

import android.content.Context
import android.net.ConnectivityManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "cine_nest/network"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getActiveHttpProxy" -> result.success(getActiveHttpProxy())
                else -> result.notImplemented()
            }
        }
    }

    private fun getActiveHttpProxy(): Map<String, Any?>? {
        val connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val activeNetwork = connectivityManager.activeNetwork ?: return null
        val linkProperties =
            connectivityManager.getLinkProperties(activeNetwork) ?: return null
        val proxy = linkProperties.httpProxy ?: return null
        val host = proxy.host?.trim()
        val port = proxy.port
        if (host.isNullOrEmpty() || port <= 0) {
            return null
        }
        return mapOf(
            "host" to host,
            "port" to port,
            "exclusionList" to proxy.exclusionList.joinToString(","),
            "pacFileUrl" to proxy.pacFileUrl?.toString()
        )
    }
}
