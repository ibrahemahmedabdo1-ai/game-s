import 'dart:math';
import 'package:shared_storage/shared_storage.dart';

/// 3 stars at or under par, 2 stars within +50%, otherwise 1.
int starsFor({required int moves, required int par}) {
  if (moves <= par) return 3;
  if (moves <= (par * 1.5).ceil()) return 2;
  return 1;
}

int scoreFor({required int level, required int moves, required int par, int bonus = 0}) {
  final base = 1000 + level * 50;
  final penalty = (moves - par).clamp(0, 1 << 20) * 25;
  return (base - penalty + bonus).clamp(100, 1 << 30);
}

int dailySeed(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

Random seededRandom(int seed) => Random(seed);

class Achievement {
  const Achievement(this.id, this.test);
  final String id;
  final bool Function(GameSave s) test;
}

final List<Achievement> standardAchievements = [
  Achievement('first_win', (s) => s.completed.isNotEmpty),
  Achievement('ten_levels', (s) => s.completed.length >= 10),
  Achievement('fifty_levels', (s) => s.completed.length >= 50),
  Achievement('three_stars_10', (s) => s.stars.values.where((v) => v == 3).length >= 10),
  Achievement('daily_streak_3', (s) => s.dailyStreak >= 3),
  Achievement('coins_500', (s) => s.coins >= 500),
];

/// Unlocks any newly satisfied achievements and returns their ids.
List<String> checkAchievements(GameSave s) {
  final out = <String>[];
  for (final a in standardAchievements) {
    if (!s.achievements.contains(a.id) && a.test(s)) {
      s.achievements.add(a.id);
      out.add(a.id);
    }
  }
  return out;
}
