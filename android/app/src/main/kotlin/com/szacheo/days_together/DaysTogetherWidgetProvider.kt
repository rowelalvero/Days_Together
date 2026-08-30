package com.szacheo.days_together

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File
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
                val imagePath = widgetData.getString("days_together_render_path", null)
                if (!imagePath.isNullOrEmpty() && File(imagePath).exists()) {
                    val bitmap = BitmapFactory.decodeFile(imagePath)
                    setImageViewBitmap(R.id.widget_card_image, bitmap)
                    setViewVisibility(R.id.widget_card_image, View.VISIBLE)
                    setViewVisibility(R.id.widget_fallback_layout, View.GONE)
                } else {
                    setViewVisibility(R.id.widget_card_image, View.GONE)
                    setViewVisibility(R.id.widget_fallback_layout, View.VISIBLE)

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

                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("daystogether://duration")).apply {
                    `package` = context.packageName
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.days_together_widget_root, pendingIntent)
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
