package com.szacheo.days_together

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class DaysTogetherWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.days_together_widget).apply {
                val startTimestamp = widgetData.getString("start_timestamp", null)
                var durationText = widgetData.getString("duration_text", null)

                if (!startTimestamp.isNullOrEmpty()) {
                    durationText = calculateDurationText(startTimestamp)
                }

                if (durationText.isNullOrEmpty()) {
                    durationText = "0 Days 00:00:00"
                }

                setTextViewText(R.id.widget_duration_text, durationText)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun calculateDurationText(isoTimestamp: String): String {
        return try {
            var startDate: Date? = null
            val formats = arrayOf(
                "yyyy-MM-dd'T'HH:mm:ss.SSS",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm"
            )
            for (fmt in formats) {
                try {
                    val sdf = SimpleDateFormat(fmt, Locale.US)
                    sdf.timeZone = TimeZone.getTimeZone("UTC")
                    startDate = sdf.parse(isoTimestamp)
                    if (startDate != null) break
                } catch (_: Exception) {}
            }

            if (startDate == null) return "0 Days 00:00:00"

            val now = Date().time
            val diff = now - startDate.time

            if (diff <= 0) return "0 Days 00:00:00"

            val totalSeconds = diff / 1000
            val days = totalSeconds / 86400
            val hours = (totalSeconds % 86400) / 3600
            val minutes = (totalSeconds % 3600) / 60
            val seconds = totalSeconds % 60

            String.format(Locale.US, "%d Days %02d:%02d:%02d", days, hours, minutes, seconds)
        } catch (e: Exception) {
            "0 Days 00:00:00"
        }
    }
}
