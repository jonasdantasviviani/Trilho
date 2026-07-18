package com.trilho.trilho

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class TrilhoWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.trilho_widget)
            
            val widgetData = HomeWidgetPlugin.getData(context)
            
            val lineName = widgetData.getString("lineName", "Selecione uma linha")
            val status = widgetData.getString("status", "Carregando...")
            val statusColor = widgetData.getString("statusColor", "#4CAF50")
            val crowdLevel = widgetData.getString("crowdLevel", "-")
            val lastUpdated = widgetData.getString("lastUpdated", "")

            views.setTextViewText(R.id.widget_line_name, lineName)
            views.setTextViewText(R.id.widget_status, status)
            views.setTextViewText(R.id.widget_crowd, "Lotação: $crowdLevel")
            views.setTextViewText(R.id.widget_updated, "Atualizado: $lastUpdated")

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
