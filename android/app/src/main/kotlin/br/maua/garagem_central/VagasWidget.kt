package br.maua.garagem_central

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.graphics.Color
import android.widget.RemoteViews

/** Widget da tela inicial: mostra quantas vagas estão livres (dado enviado pelo app). */
class VagasWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            manager.updateAppWidget(id, montar(context))
        }
    }

    companion object {
        const val PREFS = "vagavision_widget"

        fun atualizarTodos(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, VagasWidget::class.java))
            for (id in ids) {
                manager.updateAppWidget(id, montar(context))
            }
        }

        private fun montar(context: Context): RemoteViews {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val livres = prefs.getInt("livres", -1)
            val total = prefs.getInt("total", 0)
            val bloco = prefs.getString("bloco", "Bloco U") ?: "Bloco U"

            val views = RemoteViews(context.packageName, R.layout.vagas_widget)
            views.setTextViewText(R.id.widget_bloco, bloco)
            if (livres < 0) {
                // o app ainda não enviou nada
                views.setTextViewText(R.id.widget_livres, "--")
                views.setTextViewText(R.id.widget_total, "abra o app")
                views.setTextColor(R.id.widget_livres, Color.WHITE)
            } else {
                views.setTextViewText(R.id.widget_livres, livres.toString())
                views.setTextViewText(
                    R.id.widget_total,
                    if (livres == 1) "vaga livre de $total" else "vagas livres de $total",
                )
                val fracao = if (total == 0) 0.0 else livres.toDouble() / total
                val cor = when {
                    fracao > 0.5 -> Color.parseColor("#6BB74D") // sobra bastante
                    fracao > 0.2 -> Color.parseColor("#F3F33C") // ficando cheio
                    else -> Color.parseColor("#FF6B6B") // quase lotado
                }
                views.setTextColor(R.id.widget_livres, cor)
            }

            // tocar no widget abre o app
            val abrir = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (abrir != null) {
                val pendente = PendingIntent.getActivity(
                    context, 0, abrir, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_raiz, pendente)
            }
            return views
        }
    }
}
