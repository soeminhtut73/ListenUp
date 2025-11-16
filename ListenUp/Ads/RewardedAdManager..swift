//
//  RewardedAdManager..swift
//  ListenUp
//
//  Created by S M H  on 14/11/2025.
//
import UIKit
import GoogleMobileAds

final class RewardedAdManager: NSObject, FullScreenContentDelegate {
    static let shared = RewardedAdManager()
    private var ad: RewardedAd?
    private var loading = false

    // Track reward + per-presentation callbacks
    private var didEarnReward = false
    private var onDismiss: ((Bool) -> Void)?
    private var onEarned: ((AdReward) -> Void)?

    func load() {
        guard !loading, ad == nil else { return }
        loading = true
        RewardedAd.load(with: AdIDs.rewarded, request: Request()) { [weak self] ad, _ in
            guard let self else { return }
            self.loading = false
            self.ad = ad
            self.ad?.fullScreenContentDelegate = self
        }
    }

    var isReady: Bool { ad != nil }

    func present(from vc: UIViewController,
                 onEarned: ((AdReward) -> Void)? = nil,
                 onDismiss: ((Bool) -> Void)? = nil,
                 onUnavailable: (() -> Void)? = nil) {
        guard let ad = ad else {
            onUnavailable?()
            load()
            return
        }
        didEarnReward = false
        self.onEarned = onEarned
        self.onDismiss = onDismiss

        ad.present(from: vc) { [weak self] in
            guard let self else { return }
            self.didEarnReward = true
            if let onEarned = self.onEarned {
                DispatchQueue.main.async {
                    onEarned(ad.adReward)
                }
            }
        }
    }

    // MARK: - FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        let earned = didEarnReward
        didEarnReward = false
        self.ad = nil
        load()

        if let onDismiss = self.onDismiss {
            DispatchQueue.main.async { onDismiss(earned) }
        }

        self.onEarned = nil
        self.onDismiss = nil
    }
}
