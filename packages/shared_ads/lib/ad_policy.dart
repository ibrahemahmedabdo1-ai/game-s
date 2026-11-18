/// Pure-Dart ad rules so they can be unit tested without the SDK.
class InterstitialPolicy {
  InterstitialPolicy({
    required this.now,
    this.minRounds = 3,
    this.cooldown = const Duration(seconds: 120),
    this.launchGrace = const Duration(seconds: 60),
    this.maxPerSession = 8,
  }) : _launch = now();

  final DateTime Function() now;
  final int minRounds;
  final Duration cooldown, launchGrace;
  final int maxPerSession;
  final DateTime _launch;
  int _rounds = 0, _shown = 0;
  DateTime? _lastShown;

  /// Call when a round/level is completed (a natural break).
  void onRoundCompleted() => _rounds++;

  bool get canShow {
    final t = now();
    if (t.difference(_launch) < launchGrace) return false;
    if (_rounds < minRounds) return false;
    if (_shown >= maxPerSession) return false;
    if (_lastShown != null && t.difference(_lastShown!) < cooldown) return false;
    return true;
  }

  void markShown() {
    _shown++;
    _rounds = 0;
    _lastShown = now();
  }
}

/// Grants a reward only if the user-earned-reward callback fired.
class RewardTracker {
  bool _earned = false;
  bool get earned => _earned;
  void onUserEarnedReward() => _earned = true;
}
