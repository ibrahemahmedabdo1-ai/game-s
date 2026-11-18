import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ads/ad_policy.dart';
import 'package:shared_ads/admob_config.dart';

void main() {
  group('InterstitialPolicy', () {
    late DateTime clock;
    late InterstitialPolicy p;
    setUp(() {
      clock = DateTime(2026, 1, 1, 12);
      p = InterstitialPolicy(now: () => clock);
    });

    test('never right after launch', () {
      for (var i = 0; i < 5; i++) {
        p.onRoundCompleted();
      }
      expect(p.canShow, false);
    });

    test('needs min rounds and respects cooldown', () {
      clock = clock.add(const Duration(minutes: 5));
      p.onRoundCompleted();
      p.onRoundCompleted();
      expect(p.canShow, false);
      p.onRoundCompleted();
      expect(p.canShow, true);
      p.markShown();
      for (var i = 0; i < 3; i++) {
        p.onRoundCompleted();
      }
      expect(p.canShow, false); // cooldown
      clock = clock.add(const Duration(minutes: 3));
      expect(p.canShow, true);
    });

    test('session cap', () {
      final cap = InterstitialPolicy(now: () => clock, maxPerSession: 1);
      clock = clock.add(const Duration(minutes: 10));
      for (var i = 0; i < 3; i++) {
        cap.onRoundCompleted();
      }
      cap.markShown();
      clock = clock.add(const Duration(hours: 1));
      for (var i = 0; i < 3; i++) {
        cap.onRoundCompleted();
      }
      expect(cap.canShow, false);
    });
  });

  group('RewardTracker', () {
    test('no reward unless callback fired', () {
      final t = RewardTracker();
      expect(t.earned, false);
      t.onUserEarnedReward();
      expect(t.earned, true);
    });
  });

  group('AdmobConfig', () {
    test('production with placeholders disables ads', () {
      const c = AdmobConfig(
        environment: AdEnvironment.production,
        appId: 'ADMOB_APP_ID',
        bannerId: 'ADMOB_BANNER_ID',
        interstitialId: 'ADMOB_INTERSTITIAL_ID',
        rewardedId: 'ADMOB_REWARDED_ID',
      );
      expect(c.adsEnabled, false);
    });
    test('production with Google test IDs is refused', () {
      const c = AdmobConfig(
        environment: AdEnvironment.production,
        appId: GoogleTestIds.appId,
        bannerId: GoogleTestIds.banner,
        interstitialId: GoogleTestIds.interstitial,
        rewardedId: GoogleTestIds.rewarded,
      );
      expect(c.adsEnabled, false);
    });
    test('development enables test ads', () {
      final c = AdmobConfig.fromEnvironment();
      expect(c.isProduction, false);
      expect(c.adsEnabled, true);
    });
  });
}
