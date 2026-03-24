package com.example.tamago

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	companion object {
		private const val WIDGET_CHANNEL = "tamago/widget"
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
	}
}
