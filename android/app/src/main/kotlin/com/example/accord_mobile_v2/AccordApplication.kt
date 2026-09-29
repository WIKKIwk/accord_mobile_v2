package com.example.accord_mobile_v2

import android.app.Application
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import org.json.JSONObject

/** Restores public server-provided SDK options before FCM's background services run. */
class AccordApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val preferences = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        if (preferences.getString("flutter.accord.push.client_server", null).isNullOrEmpty()) return
        val raw = preferences.getString("flutter.accord.push.client_config", null) ?: return
        try {
            val config = JSONObject(raw)
            if (config.getString("application_id") != packageName) return
            val options = FirebaseOptions.Builder()
                .setProjectId(config.getString("project_id"))
                .setApplicationId(config.getString("app_id"))
                .setApiKey(config.getString("api_key"))
                .setGcmSenderId(config.getString("messaging_sender_id"))
                .build()
            if (FirebaseApp.getApps(this).isEmpty()) FirebaseApp.initializeApp(this, options)
        } catch (_: Exception) {
            Log.w("AccordPush", "Saved Firebase client configuration could not be loaded")
        }
    }
}
