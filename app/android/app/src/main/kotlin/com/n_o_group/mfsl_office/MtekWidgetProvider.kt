package com.n_o_group.mfsl_office

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home-screen widget: three live headline figures (today's sales, receipts,
 * invoices due) plus shortcut buttons that deep-link into the app.
 * Figures are written by Flutter via [MainActivity]'s "mtek/widget" channel.
 */
class MtekWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) push(context, appWidgetManager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == MainActivity.ACTION_REFRESH) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, MtekWidgetProvider::class.java))
            onUpdate(context, mgr, ids)
        }
    }

    private fun push(context: Context, mgr: AppWidgetManager, id: Int) {
        val prefs = context.getSharedPreferences(MainActivity.PREFS, Context.MODE_PRIVATE)
        val views = RemoteViews(context.packageName, R.layout.mtek_widget)

        views.setTextViewText(
            R.id.widget_sales_value,
            prefs.getString(MainActivity.KEY_SALES, MainActivity.DASH),
        )
        views.setTextViewText(
            R.id.widget_receipts_value,
            prefs.getString(MainActivity.KEY_RECEIPTS, MainActivity.DASH),
        )
        views.setTextViewText(
            R.id.widget_invoices_value,
            prefs.getString(MainActivity.KEY_INVOICES, MainActivity.DASH),
        )

        views.setOnClickPendingIntent(R.id.widget_root, openApp(context, null))
        views.setOnClickPendingIntent(R.id.widget_btn_sale, openApp(context, "sales"))
        views.setOnClickPendingIntent(R.id.widget_btn_receipts, openApp(context, "receipts"))
        views.setOnClickPendingIntent(R.id.widget_btn_stock, openApp(context, "stock"))

        mgr.updateAppWidget(id, views)
    }

    private fun openApp(context: Context, screen: String?): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(MainActivity.EXTRA_SCREEN, screen)
        }
        return PendingIntent.getActivity(
            context,
            (screen ?: "root").hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        /** Called from MainActivity whenever Flutter pushes fresh figures. */
        fun refresh(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, MtekWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val provider = MtekWidgetProvider()
            for (id in ids) provider.push(context, mgr, id)
        }
    }
}
