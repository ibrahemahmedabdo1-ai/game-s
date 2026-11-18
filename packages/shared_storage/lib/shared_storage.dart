import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class MissionDef {
  const MissionDef(this.id, this.event, this.target, this.reward);
  final String id, event;
  final int target, reward;
}

/// One mission is drawn from each group every day.
const missionGroups = <List<MissionDef>>[
  [MissionDef('round3', 'round', 3, 15), MissionDef('round6', 'round', 6, 25)],
  [MissionDef('win2', 'win', 2, 20), MissionDef('win4', 'win', 4, 35)],
  [MissionDef('stars4', 'stars', 4, 20), MissionDef('stars8', 'stars', 8, 35)],
];

/// All persisted player state for one game. Tolerant JSON parsing so that
/// future versions can add fields without breaking old saves.
class GameSave {
  int version = 1;
  int currentLevel = 1;
  final Set<int> completed = {};
  final Map<int, int> stars = {};
  int bestScore = 0;
  int coins = 0;
  int hints = 3;
  final Set<String> unlockedSkins = {'default'};
  String selectedSkin = 'default';
  bool sound = true, music = true, haptics = true;
  String language = 'en';
  String? lastDailyReward;
  int dailyStreak = 0;
  String? lastDailyChallenge;
  final Set<String> achievements = {};
  bool tutorialSeen = false;
  int roundsPlayed = 0;
  String? missionDay;
  final Map<String, int> missionProgress = {};
  final Set<String> missionClaimed = {};

  GameSave();

  void _rollMissions(DateTime now) {
    final k = dayKey(now);
    if (missionDay != k) {
      missionDay = k;
      missionProgress.clear();
      missionClaimed.clear();
    }
  }

  /// Three deterministic missions for the day.
  List<MissionDef> todaysMissions(DateTime now) {
    _rollMissions(now);
    final seed = int.parse(dayKey(now).replaceAll('-', ''));
    return [for (var g = 0; g < missionGroups.length; g++) missionGroups[g][(seed ~/ (g + 1)) % missionGroups[g].length]];
  }

  void reportEvent(String event, int amount, DateTime now) {
    for (final m in todaysMissions(now)) {
      if (m.event == event && !missionClaimed.contains(m.id)) {
        missionProgress[m.id] = ((missionProgress[m.id] ?? 0) + amount).clamp(0, m.target);
      }
    }
  }

  bool missionDone(MissionDef m) => (missionProgress[m.id] ?? 0) >= m.target;

  /// Returns coins granted (0 if not complete or already claimed).
  int claimMission(MissionDef m, DateTime now) {
    _rollMissions(now);
    if (!missionDone(m) || missionClaimed.contains(m.id)) return 0;
    missionClaimed.add(m.id);
    coins += m.reward;
    return m.reward;
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'currentLevel': currentLevel,
        'completed': completed.toList()..sort(),
        'stars': stars.map((k, v) => MapEntry('$k', v)),
        'bestScore': bestScore,
        'coins': coins,
        'hints': hints,
        'unlockedSkins': unlockedSkins.toList(),
        'selectedSkin': selectedSkin,
        'sound': sound,
        'music': music,
        'haptics': haptics,
        'language': language,
        'lastDailyReward': lastDailyReward,
        'dailyStreak': dailyStreak,
        'lastDailyChallenge': lastDailyChallenge,
        'achievements': achievements.toList(),
        'tutorialSeen': tutorialSeen,
        'roundsPlayed': roundsPlayed,
        'missionDay': missionDay,
        'missionProgress': missionProgress,
        'missionClaimed': missionClaimed.toList(),
      };

  factory GameSave.fromJson(Map<String, dynamic> j) {
    final s = GameSave();
    int i(String k, int d) => (j[k] is num) ? (j[k] as num).toInt() : d;
    bool b(String k, bool d) => j[k] is bool ? j[k] as bool : d;
    s.currentLevel = i('currentLevel', 1).clamp(1, 1 << 20);
    s.completed.addAll((j['completed'] as List? ?? []).whereType<num>().map((e) => e.toInt()));
    (j['stars'] as Map? ?? {}).forEach((k, v) {
      final key = int.tryParse('$k');
      if (key != null && v is num) s.stars[key] = v.toInt();
    });
    s.bestScore = i('bestScore', 0);
    s.coins = i('coins', 0);
    s.hints = i('hints', 3);
    s.unlockedSkins.addAll((j['unlockedSkins'] as List? ?? []).whereType<String>());
    if (s.unlockedSkins.isEmpty) s.unlockedSkins.add('default');
    s.selectedSkin = (j['selectedSkin'] as String?) ?? 'default';
    s.sound = b('sound', true);
    s.music = b('music', true);
    s.haptics = b('haptics', true);
    s.language = (j['language'] as String?) ?? 'en';
    s.lastDailyReward = j['lastDailyReward'] as String?;
    s.dailyStreak = i('dailyStreak', 0);
    s.lastDailyChallenge = j['lastDailyChallenge'] as String?;
    s.achievements.addAll((j['achievements'] as List? ?? []).whereType<String>());
    s.tutorialSeen = b('tutorialSeen', false);
    s.roundsPlayed = i('roundsPlayed', 0);
    s.missionDay = j['missionDay'] as String?;
    (j['missionProgress'] as Map? ?? {}).forEach((k, v) {
      if (v is num) s.missionProgress['$k'] = v.toInt();
    });
    s.missionClaimed.addAll((j['missionClaimed'] as List? ?? []).whereType<String>());
    return s;
  }

  bool canClaimDaily(DateTime now) => lastDailyReward != dayKey(now);

  /// Returns coins granted (0 if already claimed today).
  int claimDaily(DateTime now) {
    if (!canClaimDaily(now)) return 0;
    final yesterday = dayKey(now.subtract(const Duration(days: 1)));
    dailyStreak = lastDailyReward == yesterday ? dailyStreak + 1 : 1;
    lastDailyReward = dayKey(now);
    final reward = 20 + 5 * (dailyStreak > 7 ? 7 : dailyStreak);
    coins += reward;
    return reward;
  }

  /// Records a finished level. Keeps the best star count.
  void completeLevel(int level, int starCount, int score) {
    completed.add(level);
    if (starCount > (stars[level] ?? 0)) stars[level] = starCount;
    if (score > bestScore) bestScore = score;
    if (level >= currentLevel) currentLevel = level + 1;
  }
}

/// Persists [GameSave] with a rolling backup so a corrupt/interrupted write
/// never loses all progress.
class SaveStore {
  SaveStore(this.gameId, this._prefs);
  final String gameId;
  final SharedPreferences _prefs;
  String get _key => 'save_$gameId';
  String get _bak => 'save_${gameId}_bak';

  static Future<SaveStore> open(String gameId) async =>
      SaveStore(gameId, await SharedPreferences.getInstance());

  GameSave load() {
    for (final k in [_key, _bak]) {
      final raw = _prefs.getString(k);
      if (raw == null) continue;
      try {
        return GameSave.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {/* try backup */}
    }
    return GameSave();
  }

  Future<void> save(GameSave s) async {
    final old = _prefs.getString(_key);
    if (old != null) await _prefs.setString(_bak, old);
    await _prefs.setString(_key, jsonEncode(s.toJson()));
  }
}
