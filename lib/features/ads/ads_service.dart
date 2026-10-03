import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/ads/ads_config.dart';

enum RewardOutcome {
  /// Watched to the end.
  earned,

  /// Closed before the reward.
  skipped,

  /// No ad could be loaded or shown. Sending goes ahead anyway, so a
  /// broken ad never locks anyone out.
  unavailable,
}

/// The ad SDK behind a seam, so widget tests run without it.
abstract class AdsService {
  /// Whether this platform shows ads at all.
  bool get available;

  /// True once consent is settled and the SDK may request ads.
  ValueListenable<bool> get ready;

  /// Gathers consent where the law asks for it (UMP, which also shows the
  /// iOS tracking prompt when AdMob is set up for it), then starts the SDK.
  /// Calling it again does nothing.
  Future<void> start();

  /// A screen-width banner, or nothing until one has loaded.
  Widget banner();

  Future<RewardOutcome> showRewarded();

  /// Whether the user must be able to revisit their consent (EEA, UK).
  Future<bool> privacyOptionsRequired();

  Future<void> showPrivacyOptions();
}

/// Platforms without AdMob, such as the test host.
class NoAdsService implements AdsService {
  @override
  bool get available => false;

  @override
  final ValueListenable<bool> ready = ValueNotifier(false);

  @override
  Future<void> start() async {}

  @override
  Widget banner() => const SizedBox.shrink();

  @override
  Future<RewardOutcome> showRewarded() async => RewardOutcome.unavailable;

  @override
  Future<bool> privacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}

class GoogleAdsService implements AdsService {
  GoogleAdsService(this.config);

  final AdsConfig config;
  final _ready = ValueNotifier(false);
  Future<void>? _starting;

  @override
  bool get available => true;

  @override
  ValueListenable<bool> get ready => _ready;

  @override
  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    final settled = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired(
        (_) => settled.complete(),
      ),
      // Offline: consent given on an earlier launch still counts.
      (_) => settled.complete(),
    );
    await settled.future;
    if (!await ConsentInformation.instance.canRequestAds()) return;
    await MobileAds.instance.initialize();
    _ready.value = true;
  }

  @override
  Widget banner() => _GoogleBanner(service: this);

  @override
  Future<RewardOutcome> showRewarded() async {
    if (!_ready.value) return RewardOutcome.unavailable;
    final loading = Completer<RewardedAd?>();
    await RewardedAd.load(
      adUnitId: config.rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: loading.complete,
        onAdFailedToLoad: (_) => loading.complete(null),
      ),
    );
    final ad = await loading.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        // Too slow to be worth the wait; drop it if it shows up later.
        loading.future.then((late) => late?.dispose());
        return null;
      },
    );
    if (ad == null) return RewardOutcome.unavailable;

    var earned = false;
    var failed = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        closed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        failed = true;
        closed.complete();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    await closed.future;
    if (earned) return RewardOutcome.earned;
    return failed ? RewardOutcome.unavailable : RewardOutcome.skipped;
  }

  @override
  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptions() {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) => done.complete());
    return done.future;
  }
}

class _GoogleBanner extends StatefulWidget {
  const _GoogleBanner({required this.service});

  final GoogleAdsService service;

  @override
  State<_GoogleBanner> createState() => _GoogleBannerState();
}

class _GoogleBannerState extends State<_GoogleBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;

  @override
  void initState() {
    super.initState();
    widget.service.ready.addListener(_load);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void dispose() {
    widget.service.ready.removeListener(_load);
    _ad?.dispose();
    super.dispose();
  }

  /// Loads a banner for the current width, again after a rotation.
  Future<void> _load() async {
    if (!widget.service.ready.value || !mounted) return;
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width == _width) return;
    _width = width;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted || width != _width) return;
    final previous = _ad;
    final ad = BannerAd(
      adUnitId: widget.service.config.bannerId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted && identical(_ad, ad)) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    );
    setState(() {
      _ad = ad;
      _loaded = false;
    });
    previous?.dispose();
    await ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
