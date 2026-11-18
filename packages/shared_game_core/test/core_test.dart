import 'package:flutter_test/flutter_test.dart';
import 'package:shared_game_core/shared_game_core.dart';
import 'package:shared_storage/shared_storage.dart';

void main() {
  test('stars', () {
    expect(starsFor(moves: 5, par: 5), 3);
    expect(starsFor(moves: 7, par: 5), 2);
    expect(starsFor(moves: 20, par: 5), 1);
  });
  test('score never below 100', () {
    expect(scoreFor(level: 1, moves: 9999, par: 1), 100);
  });
  test('daily seed stable', () {
    expect(dailySeed(DateTime(2026, 11, 17)), 20261117);
  });
  test('achievements unlock once', () {
    final s = GameSave()..completeLevel(1, 3, 1000);
    expect(checkAchievements(s), contains('first_win'));
    expect(checkAchievements(s), isEmpty);
  });
}
