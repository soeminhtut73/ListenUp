//
//  PlayingIndicatorView.swift
//  ListenUp
//
//  Created by S M H  on 28/09/2025.
//

import UIKit

final class PlayingIndicatorView: UIView {
    private var isAnimating = false
    private let replicator = CAReplicatorLayer()
    private let bar = CALayer()
    private let animationKey = "eq-bounce"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        isUserInteractionEnabled = false
        backgroundColor = .clear
        
        layer.addSublayer(replicator)
        replicator.instanceCount = 3
        replicator.instanceDelay = 0.12
        
        bar.backgroundColor = UIColor.label.withAlphaComponent(0.95).cgColor
        bar.cornerRadius = 1.5
        replicator.addSublayer(bar)
        
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        replicator.frame = bounds
        
        let barWidth = max(2, bounds.width / 7)
        let barHeight = max(6, bounds.height * 0.7)
        bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: barHeight)
        bar.position = CGPoint(x: barWidth/2, y: bounds.height - 2)
        bar.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        bar.cornerRadius = barWidth/2
        
        let spacing = barWidth * 1.6
        replicator.instanceTransform = CATransform3DMakeTranslation(spacing, 0, 0)
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        // If we get re-attached (e.g. returning from background), bring animation back
        ensureRunningIfNeeded()
    }

    
    func start() {
        guard !isAnimating else { return }
        isAnimating = true
        let a = CABasicAnimation(keyPath: "transform.scale.y")
        a.fromValue = 0.35
        a.toValue = 1.0
        a.duration = 0.55
        a.autoreverses = true
        a.repeatCount = .infinity
        a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        bar.add(a, forKey: "eq-bounce")
    }
    
    func stop() {
        isAnimating = false
        bar.removeAllAnimations()
    }
    
    //MARK: - restart logic
    private func ensureRunningIfNeeded() {
        guard isAnimating, window != nil else { return }
        if bar.animation(forKey: animationKey) == nil {
            let a = CABasicAnimation(keyPath: "transform.scale.y")
            a.fromValue = 0.35
            a.toValue = 1.0
            a.duration = 0.55
            a.autoreverses = true
            a.repeatCount = .infinity
            a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bar.add(a, forKey: animationKey)
        }
    }
    
    @objc private func appDidBecomeActive() {
        ensureRunningIfNeeded()
    }
}
