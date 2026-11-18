import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_policy.dart';
import 'admob_config.dart';

/// One instance per app. Never shows ads before consent allows requests.
class AdsService {
  AdsService(this.config, {InterstitialPolicy? policy})
      : policy = policy ?? InterstitialPolicy(now: DateTime.now);

  final AdmobConfig config;
  final InterstitialPolicy policy;

  bool _ready = false;
  bool get ready => _ready && config.adsEnabled;
  bool _privacyOptionsRequired = false;
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _loadingInterstitial = false, _loadingRewarded = false;

  /// UMP consent first, then SDK init. Safe to call once at startup.
  Future<void> initialize() async {
    if (!config.adsEnabled) return;
    try {
      await _requestConsent();
      if (!await ConsentInformation.instance.canRequestAds()) return;
      if (config.testDeviceIds.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
            RequestConfiguration(testDeviceIds: config.testDeviceIds));
      }
      await MobileAds.instance.initialize();
      _ready = true;
      _privacyOptionsRequired = await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      _loadInterstitial();
      _loadRewarded();
    } catch (e) {
      debugPrint('Ads init failed (game continues offline): $e');
    }
  }

  Future<void> _requestConsent() {
    final c = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) {
          if (!c.isCompleted) c.complete();
        });
      },
      (FormError e) {
        if (!c.isCompleted) c.complete();
      },
    );
    return c.future.timeout(const Duration(seconds: 20), onTimeout: () {});
  }

  Future<void> showPrivacyOptions() async {
    final c = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? e) => c.complete());
    await c.future;
  }

  void _loadInterstitial() {
    if (!ready || _interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: config.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (_) => _loadingInterstitial = false,
      ),
    );
  }

  void _loadRewarded() {
    if (!ready || _rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: config.rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
        },
        onAdFailedToLoad: (_) => _loadingRewarded = false,
      ),
    );
  }

  bool get rewardedAvailable => ready && _rewarded != null;

  /// Call at natural breaks (level complete / game over screen) only.
  /// [onShowing]/[onClosed] let the game pause and resume.
  void roundCompleted({VoidCallback? onShowing, VoidCallback? onClosed}) {
    policy.onRoundCompleted();
    if (!ready || !policy.canShow) return;
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => onShowing?.call(),
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        onClosed?.call();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        onClosed?.call();
        _loadInterstitial();
      },
    );
    policy.markShown();
    ad.show();
  }

  /// Resolves true ONLY if the SDK reported the user earned the reward.
  /// The caller must grant the promised reward only when this returns true.
  Future<bool> showRewarded({VoidCallback? onShowing, VoidCallback? onClosed}) {
    final ad = _rewarded;
    if (!ready || ad == null) {
      _loadRewarded();
      return Future.value(false);
    }
    _rewarded = null;
    final tracker = RewardTracker();
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => onShowing?.call(),
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        onClosed?.call();
        _loadRewarded();
        if (!done.isCompleted) done.complete(tracker.earned);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        onClosed?.call();
        _loadRewarded();
        if (!done.isCompleted) done.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (_, __) => tracker.onUserEarnedReward());
    return done.future;
  }
}

/// Adaptive banner for menus / level select only. Never place on gameplay.
class AdaptiveBanner extends StatefulWidget {
  const AdaptiveBanner({super.key, required this.ads});
  final AdsService ads;
  @override
  State<AdaptiveBanner> createState() => _AdaptiveBannerState();
}

class _AdaptiveBannerState extends State<AdaptiveBanner> {
  BannerAd? _ad;
  bool _loaded = false, _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested || !widget.ads.ready) return;
    _requested = true;
    _load();
  }

  Future<void> _load() async {
    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;
    final ad = BannerAd(
      adUnitId: widget.ads.config.bannerId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
    _ad = ad;
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The SDK may finish initialising after this widget was first built.
    if (!_requested && widget.ads.ready) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: _ad!.size.width.toDouble(),
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
