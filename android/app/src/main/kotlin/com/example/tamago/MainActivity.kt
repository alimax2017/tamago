package com.estel.tamago

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	companion object {
		private const val WIDGET_CHANNEL = "tamago/widget"
		private const val NOTIF_CHANNEL = "tamago/notifications"
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"updateTodayTasksWidget" -> {
						TodayTasksWidgetProvider.updateAllWidgets(applicationContext)
						result.success(true)
					}
					else -> result.notImplemented()
				}
			}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"requestIgnoreBatteryOptimizations" -> {
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
							val pm = getSystemService(POWER_SERVICE) as PowerManager
							if (!pm.isIgnoringBatteryOptimizations(packageName)) {
								val intent = Intent(
									Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
								)
								intent.data = Uri.parse("package:$packageName")
								startActivity(intent)
							}
						}
						result.success(true)
					}
					"isIgnoringBatteryOptimizations" -> {
						var ignoring = true
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
							val pm = getSystemService(POWER_SERVICE) as PowerManager
							ignoring = pm.isIgnoringBatteryOptimizations(packageName)
						}
						result.success(ignoring)
					}
					else -> result.notImplemented()
				}
			}
	}
}
