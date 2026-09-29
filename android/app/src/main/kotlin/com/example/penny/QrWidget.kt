package com.example.penny

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The receive QR, as a PNG the app rendered with Flutter.
 *
 * `qr_image` holds the file's path, or is absent when there is no UPI ID yet,
 * in which case the widget says where to add one.
 */
class QrWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        // A missing or unreadable file decodes to null and falls back to the
        // hint, rather than leaving an empty square on the home screen.
        val bitmap = widgetData.getString("qr_image", null)?.let { BitmapFactory.decodeFile(it) }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_qr).apply {
                if (bitmap != null) {
                    setImageViewBitmap(R.id.qr_image, bitmap)
                    setViewVisibility(R.id.qr_image, View.VISIBLE)
                    setViewVisibility(R.id.qr_empty, View.GONE)
                } else {
                    setViewVisibility(R.id.qr_image, View.GONE)
                    setViewVisibility(R.id.qr_empty, View.VISIBLE)
                }
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
