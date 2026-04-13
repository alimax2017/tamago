package com.estel.tamago

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class TodayTasksWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        updateAllWidgets(context)
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val TASKS_KEY = "flutter.tamago_tasks_v1"

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, TodayTasksWidgetProvider::class.java)
            val widgetIds = manager.getAppWidgetIds(component)

            for (widgetId in widgetIds) {
                val views = RemoteViews(context.packageName, R.layout.today_tasks_widget)
                views.setTextViewText(R.id.widget_title, "Today's tasks")
                views.setTextViewText(R.id.widget_tasks, buildTodayTasksText(context))
                views.setOnClickPendingIntent(R.id.widget_root, openAppPendingIntent(context))
                manager.updateAppWidget(widgetId, views)
            }
        }

        private fun openAppPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return PendingIntent.getActivity(context, 0, intent, flags)
        }

        private fun buildTodayTasksText(context: Context): String {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(TASKS_KEY, null).orEmpty()
            if (raw.isBlank()) {
                return "Aucune tache pour aujourd'hui"
            }

            val tasks = try {
                JSONArray(raw)
            } catch (_: Exception) {
                return "Aucune tache pour aujourd'hui"
            }

            val today = todayAtMidnight()
            val lines = mutableListOf<String>()

            for (i in 0 until tasks.length()) {
                val item = tasks.optJSONObject(i) ?: continue
                val status = item.optString("status", "")
                if (status == "Terminé") {
                    continue
                }

                if (!occursToday(item, today)) {
                    continue
                }

                val title = item.optString("name", "").trim().ifEmpty { "Tache" }
                val start = item.optInt("startTime", -1)
                val end = item.optInt("endTime", -1)
                val timeLabel = if (start >= 0 && end >= 0) {
                    " (${minutesToTime(start)} - ${minutesToTime(end)})"
                } else {
                    ""
                }
                lines.add("• $title$timeLabel")
            }

            if (lines.isEmpty()) {
                return "Aucune tache pour aujourd'hui"
            }

            // Keep widget compact and readable.
            return lines.take(6).joinToString(separator = "\n")
        }

        private fun occursToday(task: JSONObject, today: Calendar): Boolean {
            val taskDate = parseIsoDate(task.optString("date", "")) ?: return false
            val endDate = parseIsoDate(task.optString("endDate", "")) ?: taskDate

            if (today.before(taskDate) || today.after(endDate)) {
                return false
            }

            return when (val recurrence = task.optString("recurrence", "Aucune")) {
                "Aucune" -> true
                "Quotidienne" -> true
                "Hebdomadaire" -> today.get(Calendar.DAY_OF_WEEK) == taskDate.get(Calendar.DAY_OF_WEEK)
                "Mensuelle" -> today.get(Calendar.DAY_OF_MONTH) == taskDate.get(Calendar.DAY_OF_MONTH)
                else -> {
                    if (recurrence.startsWith("Jours:")) {
                        val rawDays = recurrence.removePrefix("Jours:")
                            .split(',')
                            .map { it.trim() }
                            .filter { it.isNotEmpty() }
                        val weekdays = rawDays.mapNotNull { frenchDayToCalendarDay(it) }.toSet()
                        weekdays.contains(today.get(Calendar.DAY_OF_WEEK))
                    } else {
                        isSameDay(today, taskDate)
                    }
                }
            }
        }

        private fun frenchDayToCalendarDay(label: String): Int? {
            return when (label) {
                "Lundi" -> Calendar.MONDAY
                "Mardi" -> Calendar.TUESDAY
                "Mercredi" -> Calendar.WEDNESDAY
                "Jeudi" -> Calendar.THURSDAY
                "Vendredi" -> Calendar.FRIDAY
                "Samedi" -> Calendar.SATURDAY
                "Dimanche" -> Calendar.SUNDAY
                else -> null
            }
        }

        private fun parseIsoDate(raw: String): Calendar? {
            if (raw.isBlank()) return null
            val datePart = if (raw.length >= 10) raw.substring(0, 10) else raw
            val parser = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val parsed: Date = try {
                parser.parse(datePart) ?: return null
            } catch (_: Exception) {
                return null
            }
            return Calendar.getInstance().apply {
                time = parsed
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
        }

        private fun todayAtMidnight(): Calendar {
            return Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
        }

        private fun isSameDay(a: Calendar, b: Calendar): Boolean {
            return a.get(Calendar.YEAR) == b.get(Calendar.YEAR) &&
                a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
        }

        private fun minutesToTime(minutes: Int): String {
            val h = minutes / 60
            val m = minutes % 60
            return "%02d:%02d".format(Locale.US, h, m)
        }
    }
}
