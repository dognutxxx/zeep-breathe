import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'audio/music_service.dart';
import 'haptics/haptics_service.dart';
import 'screens/session_screen.dart';
import 'screens/setup_screen.dart';
import 'settings/settings_controller.dart';
import 'ui/widgets.dart';
import 'ui/zeep_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final settings = SettingsController();
  await settings.load();
  final haptics = HapticsService(enabled: settings.vibration);
  final music = MusicService();
  await Future.wait([haptics.init(), music.init()]);

  runApp(ZeepBreatheApp(controller: AppController(settings: settings, haptics: haptics, music: music)));
}

class ZeepBreatheApp extends StatelessWidget {
  final AppController controller;
  const ZeepBreatheApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZEEP Breathe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: ZeepColors.blue, surface: Colors.white),
        scaffoldBackgroundColor: ZeepColors.bgBottom,
      ),
      home: HomePage(app: controller),
    );
  }
}

class HomePage extends StatefulWidget {
  final AppController app;
  const HomePage({super.key, required this.app});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // One ticker drives engine, character, bar, label, haptics and music.
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      widget.app.tick(dt);
    })
      ..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      widget.app.pauseIfRunning();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.app.reduceMotion = MediaQuery.of(context).disableAnimations;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    widget.app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZeepBackground(
        // iPad / landscape: keep the phone-width column centred
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListenableBuilder(
              listenable: widget.app,
              builder: (context, _) => switch (widget.app.screen) {
                Screen.setup => SetupScreen(app: widget.app),
                Screen.session => SessionScreen(app: widget.app),
              },
            ),
          ),
        ),
      ),
    );
  }
}
