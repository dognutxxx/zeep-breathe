import 'dart:async';
import 'dart:ui' as ui;

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
import 'screens/splash_screen.dart';
import 'screens/wardrobe_cards.dart';
import 'settings/settings_controller.dart';
import 'ui/beta_banner.dart';
import 'ui/widgets.dart';
import 'ui/zeep_colors.dart';
import 'wardrobe/wardrobe_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Draw behind the status and navigation bars, as on iOS: the view then
  // fills the whole window, so the splash logo sits exactly where the native
  // launch screen drew it (no jump, no grey bars). MainActivity.kt sets the
  // window up for every Android version (bar colours too, since Android 7
  // can't show dark navigation icons); screens keep clear with SafeArea.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  // Show the splash at once and load while it plays (it waits for this).
  final boot = loadApp();
  final logo = await loadSplashLogo();
  runApp(ZeepBreatheApp(boot: boot, splashLogo: logo));
}

/// Loads settings, haptics, audio, history and the wardrobe.
Future<AppController> loadApp() async {
  final settings = SettingsController();
  await settings.load();
  final haptics = HapticsService(enabled: settings.vibration);
  final music = MusicService();
  final history = SessionHistory();
  // a stuck platform channel must not keep the splash waiting forever
  await Future.wait([
    haptics.init().timeout(const Duration(seconds: 3), onTimeout: () {}),
    music.init().timeout(const Duration(seconds: 3), onTimeout: () {}),
    history.load(),
  ]);
  final wardrobe = WardrobeController();
  await wardrobe.load(history.records);
  return AppController(settings: settings, haptics: haptics, music: music, history: history, wardrobe: wardrobe);
}

class ZeepBreatheApp extends StatelessWidget {
  /// A ready app (tests, screenshots): no splash.
  final AppController? controller;

  /// Cold start: the splash plays while this loads.
  final Future<AppController>? boot;

  /// The splash logo, decoded before the first frame.
  final ui.Image? splashLogo;

  const ZeepBreatheApp({super.key, this.controller, this.boot, this.splashLogo})
    : assert(controller != null || boot != null);

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
      home: controller != null ? HomePage(app: controller!) : LaunchGate(boot: boot!, logo: splashLogo),
    );
  }
}

/// The splash on top; the app goes underneath once loaded and the splash
/// starts fading. Only on a cold start: coming back from the background
/// doesn't rebuild this.
class LaunchGate extends StatefulWidget {
  final Future<AppController> boot;

  /// Splash speed (0.5 = the approved half speed); tests may speed it up.
  final double splashSpeed;
  final ui.Image? logo;

  const LaunchGate({super.key, required this.boot, this.splashSpeed = 0.5, this.logo});

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  final _splashGone = Completer<void>();
  AppController? _app;
  bool _showApp = false, _splashDone = false;

  @override
  void initState() {
    super.initState();
    widget.boot.then(
      (app) {
        if (mounted) setState(() => _app = app);
      },
      onError: (Object e, StackTrace st) {
        FlutterError.reportError(FlutterErrorDetails(exception: e, stack: st, library: 'zeep launch'));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    return Stack(
      children: [
        if (app != null && _showApp)
          HomePage(app: app, splashGone: _splashGone.future)
        else
          const ColoredBox(color: splashBackground, child: SizedBox.expand()),
        if (!_splashDone)
          SplashScreen(
            ready: widget.boot,
            speed: widget.splashSpeed,
            logo: widget.logo,
            onReveal: () => setState(() => _showApp = true),
            onDone: () {
              if (!_splashGone.isCompleted) _splashGone.complete();
              setState(() => _splashDone = true);
              // the splash never comes back in this run: free its images
              WidgetsBinding.instance.addPostFrameCallback((_) {
                evictSplashImages();
                widget.logo?.dispose();
              });
            },
          ),
      ],
    );
  }
}

class HomePage extends StatefulWidget {
  final AppController app;

  /// Completes when the launch splash is gone; one-off cards wait for it.
  final Future<void>? splashGone;
  const HomePage({super.key, required this.app, this.splashGone});

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
    // people who practised before the wardrobe existed: one summary card
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.splashGone;
      if (mounted && widget.app.wardrobe.summaryPending) showSummaryCard(context, widget.app);
    });
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
