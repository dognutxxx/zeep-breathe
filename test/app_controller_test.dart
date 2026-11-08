import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeep_breathe/app_controller.dart';
import 'package:zeep_breathe/audio/music_service.dart';
import 'package:zeep_breathe/haptics/haptics_service.dart';
import 'package:zeep_breathe/settings/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 11, 20, 22, 30);
  final picked = DateTime(2026, 11, 17);

  Future<AppController> make() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();
    return AppController(settings: settings, haptics: HapticsService(), music: MusicService())
      ..clock = (() => now)
      ..progressDay = picked
      ..progressMonth = DateTime(2026, 11);
  }

  test('a saved session (stopped after 30 s) sends the calendar back to today', () async {
    final app = await make();
    app.startSession();
    app.engine.sessionElapsed = 45;
    app.stopSession();
    expect(app.history.records, hasLength(1));
    expect(app.progressDay, isNull);
    expect(app.progressMonth, isNull);
  });

  test('a session stopped before 30 s is not saved and keeps the picked day', () async {
    final app = await make();
    app.startSession();
    app.engine.sessionElapsed = 10;
    app.stopSession();
    expect(app.history.records, isEmpty);
    expect(app.progressDay, picked);
    expect(app.progressMonth, DateTime(2026, 11));
  });
}
