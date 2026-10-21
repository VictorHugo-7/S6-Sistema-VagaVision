package br.maua.garagem_central

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // O app (Dart) manda as vagas livres; aqui guardamos e atualizamos o widget da tela inicial.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "br.maua.garagem_central/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "atualizar") {
                    val livres = call.argument<Int>("livres") ?: 0
                    val total = call.argument<Int>("total") ?: 0
                    val bloco = call.argument<String>("bloco") ?: "Bloco U"
                    getSharedPreferences(VagasWidget.PREFS, Context.MODE_PRIVATE)
                        .edit()
                        .putInt("livres", livres)
                        .putInt("total", total)
                        .putString("bloco", bloco)
                        .apply()
                    VagasWidget.atualizarTodos(applicationContext)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
