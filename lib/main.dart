import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'garagem_controller.dart';
import 'garagem_scene.dart';
import 'hud.dart';
import 'theme.dart';

void main() => runApp(const GaragemApp());

class GaragemApp extends StatefulWidget {
  const GaragemApp({super.key});

  @override
  State<GaragemApp> createState() => _GaragemAppState();
}

class _GaragemAppState extends State<GaragemApp> {
  final _controller = GaragemController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return MaterialApp(
      title: 'Garagem Central',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Cores.asfalto,
        colorScheme: ColorScheme.fromSeed(seedColor: Cores.amarelo, brightness: Brightness.dark),
      ),
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: GaragemScene(controller: _controller)),
            Positioned.fill(child: Hud(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
