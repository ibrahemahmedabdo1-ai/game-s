/// Central AdMob configuration.
///
/// Values come from `--dart-define` so nothing real is committed:
///   --dart-define=ADMOB_ENV=development|production
///   --dart-define=ADMOB_APP_ID=ca-app-pub-xxx~yyy
///   --dart-define=ADMOB_BANNER_ID=...  ADMOB_INTERSTITIAL_ID=...  ADMOB_REWARDED_ID=...
///   --dart-define=ADMOB_TEST_DEVICES=id1,id2
enum AdEnvironment { development, production }

/// Google's official public demo IDs (Android). Safe for development only.
class GoogleTestIds {
  static const appId = 'ca-app-pub-3940256099942544~3347511713';
  static const banner = 'ca-app-pub-3940256099942544/9214589741';
  static const interstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const rewarded = 'ca-app-pub-3940256099942544/5224354917';
}

class AdmobConfig {
  const AdmobConfig({
    required this.environment,
    required this.appId,
    required this.bannerId,
    required this.interstitialId,
    required this.rewardedId,
    this.testDeviceIds = const [],
  });

  final AdEnvironment environment;
  final String appId, bannerId, interstitialId, rewardedId;
  final List<String> testDeviceIds;

  static const _env = String.fromEnvironment('ADMOB_ENV', defaultValue: 'development');
  static const _app = String.fromEnvironment('ADMOB_APP_ID', defaultValue: 'ADMOB_APP_ID');
  static const _banner = String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: 'ADMOB_BANNER_ID');
  static const _inter = String.fromEnvironment('ADMOB_INTERSTITIAL_ID', defaultValue: 'ADMOB_INTERSTITIAL_ID');
  static const _rew = String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: 'ADMOB_REWARDED_ID');
  static const _devices = String.fromEnvironment('ADMOB_TEST_DEVICES');

  /// Development uses Google demo IDs. Production uses the supplied IDs; if
  /// any are still placeholders, ads stay disabled (never silently test ads).
  factory AdmobConfig.fromEnvironment() {
    final production = _env == 'production';
    final devices = _devices.isEmpty ? <String>[] : _devices.split(',');
    if (!production) {
      return AdmobConfig(
        environment: AdEnvironment.development,
        appId: GoogleTestIds.appId,
        bannerId: GoogleTestIds.banner,
        interstitialId: GoogleTestIds.interstitial,
        rewardedId: GoogleTestIds.rewarded,
        testDeviceIds: devices,
      );
    }
    return AdmobConfig(
      environment: AdEnvironment.production,
      appId: _app,
      bannerId: _banner,
      interstitialId: _inter,
      rewardedId: _rew,
      testDeviceIds: devices,
    );
  }

  static bool isPlaceholder(String v) =>
      v.isEmpty || v.startsWith('ADMOB_') || !v.startsWith('ca-app-pub-');

  bool get isProduction => environment == AdEnvironment.production;

  /// Ads run in development (test ads) or in production with all real IDs set.
  bool get adsEnabled {
    if (!isProduction) return true;
    return ![appId, bannerId, interstitialId, rewardedId].any(isPlaceholder) &&
        !_usesGoogleTestIds;
  }

  bool get _usesGoogleTestIds => [bannerId, interstitialId, rewardedId]
      .any((v) => v.startsWith('ca-app-pub-3940256099942544'));
}
