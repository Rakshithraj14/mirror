package com.example.penny

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Spent today, the daily average and the untagged count.
 *
 * Every string arrives pre-formatted from Dart (lib/services/home_widgets.dart),
 * so this only places them. The one decision made here is the date check.
 */
class TodayWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        // Written yesterday and nothing has run since midnight: yesterday's
        // total under a "Today" label would be wrong, and today is ₹0 so far.
        val fresh = widgetData.getString("today_day", null) == today
        val spent = if (fresh) widgetData.getString("today_spent", null) ?: "₹0" else "₹0"
        val average = widgetData.getString("today_average", null).orEmpty()
        val untagged = widgetData.getString("today_untagged", null).orEmpty()

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_today).apply {
                setTextViewText(R.id.today_spent, spent)
                setTextViewText(R.id.today_average, average)
                setViewVisibility(R.id.today_average, if (average.isEmpty()) View.GONE else View.VISIBLE)
                setTextViewText(R.id.today_untagged, untagged)
                setViewVisibility(R.id.today_untagged, if (untagged.isEmpty()) View.GONE else View.VISIBLE)
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
