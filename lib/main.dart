import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'audio/music_service.dart';
import 'haptics/haptics_service.dart';
import 'history/session_history.dart';
import 'l10n/strings.dart';
import 'screens/exercises_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/session_screen.dart';
import 'screens/setup_screen.dart';
import 'settings/settings_controller.dart';
import 'ui/beta_banner.dart';
import 'ui/widgets.dart';
import 'ui/zeep_colors.dart';
import 'wardrobe/wardrobe_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final settings = SettingsController();
  await settings.load();
  final haptics = HapticsService(enabled: settings.vibration);
  final music = MusicService();
  final history = SessionHistory();
  await Future.wait([haptics.init(), music.init(), history.load()]);
  final wardrobe = WardrobeController();
  await wardrobe.load(history.records);

  runApp(
    ZeepBreatheApp(
      controller: AppController(
        settings: settings,
        haptics: haptics,
        music: music,
        history: history,
        wardrobe: wardrobe,
      ),
    ),
  );
}

class ZeepBreatheApp extends StatelessWidget {
  final AppController controller;
  const ZeepBreatheApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZEEP Breathe',
      debugShowCheckedModeBanner: false,
      // Thai when the phone is set to Thai, otherwise English
      supportedLocales: S.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
    })..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      widget.app.pauseIfRunning();
      // no more frames in the background on Android: stop the fade now
      widget.app.music.stopNow();
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
    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final app = widget.app;
        final l = S.of(context);
        final inSession = app.screen == Screen.session;
        final Widget page = inSession
            ? SessionScreen(app: app)
            : switch (app.tab) {
                HomeTab.breathe => SetupScreen(app: app),
                HomeTab.exercises => ExercisesScreen(app: app),
                HomeTab.progress => ProgressScreen(app: app),
              };
        return Scaffold(
          body: ZeepBackground(
            // iPad / landscape: keep the phone-width column centred
            child: Column(
              children: [
                if (!inSession) BetaBanner(app: app),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: page),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: inSession
              ? null
              : NavigationBar(
                  height: 64,
                  backgroundColor: Colors.white,
                  indicatorColor: ZeepColors.blueSoft,
                  surfaceTintColor: Colors.transparent,
                  selectedIndex: app.tab.index,
                  onDestinationSelected: (i) => app.setTab(HomeTab.values[i]),
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.spa_outlined),
                      selectedIcon: const Icon(Icons.spa_rounded),
                      label: l.tabBreathe,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.grid_view_outlined),
                      selectedIcon: const Icon(Icons.grid_view_rounded),
                      label: l.tabExercises,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.insights_outlined),
                      selectedIcon: const Icon(Icons.insights_rounded),
                      label: l.tabProgress,
                    ),
                  ],
                ),
        );
      },
    );
  }
}
