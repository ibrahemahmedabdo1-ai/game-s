import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_storage/shared_storage.dart';

void main() {
  test('save and restore round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SaveStore.open('t');
    final s = GameSave()
      ..coins = 42
      ..sound = false
      ..language = 'ar';
    s.completeLevel(1, 3, 900);
    await store.save(s);
    final r = (await SaveStore.open('t')).load();
    expect(r.coins, 42);
    expect(r.sound, false);
    expect(r.language, 'ar');
    expect(r.currentLevel, 2);
    expect(r.stars[1], 3);
    expect(r.bestScore, 900);
  });

  test('corrupt save falls back to backup then default', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SaveStore.open('t');
    await store.save(GameSave()..coins = 5);
    await store.save(GameSave()..coins = 6);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('save_t', '{broken');
    expect(store.load().coins, 5);
    await prefs.setString('save_t_bak', 'xx');
    expect(store.load().coins, 0);
  });

  test('daily reward once per day and streak', () {
    final s = GameSave();
    final d1 = DateTime(2026, 11, 1, 10);
    expect(s.claimDaily(d1), 25);
    expect(s.claimDaily(d1), 0);
    expect(s.claimDaily(DateTime(2026, 11, 2)), 30);
    expect(s.dailyStreak, 2);
    s.claimDaily(DateTime(2026, 11, 5));
    expect(s.dailyStreak, 1);
  });

  test('daily missions: three per day, progress, claim once, reset next day', () {
    final s = GameSave();
    final d = DateTime(2026, 11, 18, 9);
    final ms = s.todaysMissions(d);
    expect(ms.length, 3);
    expect(ms.map((m) => m.event).toSet(), {'round', 'win', 'stars'});
    final win = ms.firstWhere((m) => m.event == 'win');
    s.reportEvent('win', 1, d);
    expect(s.missionDone(win), false);
    expect(s.claimMission(win, d), 0);
    s.reportEvent('win', 10, d);
    expect(s.missionDone(win), true);
    expect(s.claimMission(win, d), win.reward);
    expect(s.claimMission(win, d), 0);
    final round = GameSave.fromJson(s.toJson());
    expect(round.missionClaimed, contains(win.id));
    s.todaysMissions(DateTime(2026, 11, 19));
    expect(s.missionProgress, isEmpty);
    expect(s.missionClaimed, isEmpty);
  });
}
