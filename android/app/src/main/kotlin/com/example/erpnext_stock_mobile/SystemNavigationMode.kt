package com.example.erpnext_stock_mobile

import android.content.Context
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Tizim navigatsiyasi: gesture vs tugmalar.
 *
 * [Settings.Secure] `navigation_mode` (AOSP talqiniga yaqin):
 * - **2** → to‘liq gesture navigatsiya (ingichka pastki UX uchun `true`).
 * - **1** → 2 tugma.
 * - **0** → 3 tugma.
 *
 * MIUI da `use_gesture_version_three` gesture bilan bog‘liq bo‘lsa-da, **3 tugma** rejimida ham 1
 * bo‘lishi mumkin — shuning uchun **faqat `navigation_mode == 2`** ishonchli `true` uchun ishlatiladi.
 * Baʼzi Xiaomi qurilmalarda gesture bo‘lsa ham `navigation_mode` noto‘g‘ri bo‘lsa, pastki zona
 * to‘liq inset bilan qoladi (xavfsiz).
 */
object SystemNavigationMode {
    /** Raw [Settings.Secure] `navigation_mode`; yo‘q bo‘lsa -1. */
    fun secureNavigationMode(context: Context): Int =
        try {
            Settings.Secure.getInt(context.contentResolver, "navigation_mode", -1)
        } catch (_: Settings.SettingNotFoundException) {
            -1
        }

    /** Raw [Settings.Global] `use_gesture_version_three` (asosan Xiaomi). */
    fun miuiGestureVersionThree(context: Context): Int =
        try {
            Settings.Global.getInt(context.contentResolver, "use_gesture_version_three", 0)
        } catch (_: Settings.SettingNotFoundException) {
            0
        }

    /**
     * `true` faqat `navigation_mode == 2` bo‘lsa — tugmali rejimda noto‘g‘ri ingichka zona bermaslik uchun.
     */
    fun isGestureNavigation(context: Context): Boolean =
        secureNavigationMode(context) == 2

    fun debugSnapshot(context: Context): Map<String, Any?> =
        mapOf(
            "navigation_mode" to secureNavigationMode(context),
            "use_gesture_version_three" to miuiGestureVersionThree(context),
            "isGestureNavigation" to isGestureNavigation(context),
        )
}

/**
 * Flutter: kanal `accord/system_navigation`.
 */
class SystemNavigationModeChannel(
    messenger: BinaryMessenger,
    private val context: Context,
) {
    private val channel = MethodChannel(messenger, "accord/system_navigation")

    init {
        channel.setMethodCallHandler { call, result ->
            val appContext = context.applicationContext
            when (call.method) {
                "isGestureNavigation" ->
                    result.success(SystemNavigationMode.isGestureNavigation(appContext))
                "debugSnapshot" ->
                    result.success(SystemNavigationMode.debugSnapshot(appContext))
                else -> result.notImplemented()
            }
        }
    }
}
