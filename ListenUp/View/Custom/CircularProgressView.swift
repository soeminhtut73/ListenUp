//
//  CircularProgressView.swift
//  ListenUp
//
//  Created by S M H on 23/10/2025.
//

import UIKit

class CircularProgressView: UIView {
    
    // MARK: - Properties
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let iconImageView = UIImageView()
    
    private var currentProgress: CGFloat = 0
    private var currentItemId: String? = nil  // Track which item we're showing
    
    // Customization
    var trackColor: UIColor = UIColor.systemGray5 {
        didSet {
            trackLayer.strokeColor = trackColor.cgColor
        }
    }
    
    var progressColor: UIColor = UIColor.systemBlue {
        didSet {
            progressLayer.strokeColor = progressColor.cgColor
            updateIcon()
        }
    }
    
    var lineWidth: CGFloat = 30 {
        didSet {
            trackLayer.lineWidth = lineWidth
            progressLayer.lineWidth = lineWidth
            setNeedsLayout()
        }
    }
    
    var showIcon: Bool = true {
        didSet {
            iconImageView.isHidden = !showIcon
        }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
        setupIconView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
        setupIconView()
    }
    
    // MARK: - Setup
    private func setupLayers() {
        backgroundColor = .clear
        
        // Track layer (background circle)
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = trackColor.cgColor
        trackLayer.lineWidth = lineWidth
        trackLayer.lineCap = .round
        layer.addSublayer(trackLayer)
        
        // Progress layer (foreground circle that fills)
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = progressColor.cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        layer.addSublayer(progressLayer)
    }
    
    private func setupIconView() {
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = progressColor
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)
        
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.4),
            iconImageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.4)
        ])
        
        updateIcon()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
        
        let circularPath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: 3 * .pi / 2,
            clockwise: true
        )
        
        trackLayer.path = circularPath.cgPath
        progressLayer.path = circularPath.cgPath
    }
    
    // MARK: - Public Methods
    
    /// Set progress with animation (0.0 to 1.0)
    /// Call this without itemId for simple progress updates
    func setProgress(_ progress: Double, animated: Bool = true) {
        setProgress(progress, for: nil, animated: animated)
    }
    
    /// Set progress for a specific item (recommended for table view cells)
    /// This prevents backward animation when cell is reused for different items
    func setProgress(_ progress: Double, for itemId: String?, animated: Bool = true) {
        let clampedProgress = CGFloat(max(0.0, min(progress, 1.0)))
        
        // Check if this is a different item
        let isDifferentItem = itemId != nil && itemId != currentItemId
        
        if isDifferentItem {
            // Different item - reset immediately without animation
            currentItemId = itemId
            progressLayer.removeAllAnimations()
            progressLayer.strokeEnd = 0
            currentProgress = 0
            updateIcon()
            
            // Then animate to new progress if non-zero
            if clampedProgress > 0 {
                DispatchQueue.main.async {
                    self.animateProgress(to: clampedProgress, animated: animated)
                }
            }
            return
        }
        
        // Same item - check if progress is going backwards
        let isGoingBackwards = clampedProgress < currentProgress - 0.01 // Small threshold for rounding
        
        if isGoingBackwards {
            // Progress decreased - this shouldn't normally happen
            // Reset and animate to new value
            progressLayer.removeAllAnimations()
            progressLayer.strokeEnd = 0
            currentProgress = 0
            updateIcon()
            
            if clampedProgress > 0 {
                DispatchQueue.main.async {
                    self.animateProgress(to: clampedProgress, animated: animated)
                }
            }
        } else {
            // Normal forward progress or staying same
            animateProgress(to: clampedProgress, animated: animated)
        }
    }
    
    /// Reset progress to 0 and clear item tracking
    func reset(animated: Bool = false) {
        currentItemId = nil
        currentProgress = 0
        
        if animated {
            animateProgress(to: 0, animated: true)
        } else {
            progressLayer.removeAllAnimations()
            progressLayer.strokeEnd = 0
            updateIcon()
        }
    }
    
    /// Set to completed state
    func setCompleted(for itemId: String? = nil) {
        currentItemId = itemId
        setProgress(1.0, for: itemId, animated: true)
        
        // Pulse animation on completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.pulseAnimation()
        }
    }
    
    // MARK: - Private Methods
    private func animateProgress(to progress: CGFloat, animated: Bool) {
        let oldProgress = currentProgress
        currentProgress = progress
        
        if animated && abs(progress - oldProgress) > 0.001 {
            // Remove existing animation
            progressLayer.removeAnimation(forKey: "strokeEndAnimation")
            
            // Use presentation layer for smooth transitions
            let fromValue = progressLayer.presentation()?.strokeEnd ?? progressLayer.strokeEnd
            
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = fromValue
            animation.toValue = progress
            animation.duration = 0.3
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            
            progressLayer.add(animation, forKey: "strokeEndAnimation")
        }
        
        progressLayer.strokeEnd = progress
        updateIcon()
    }
    
    private func updateIcon() {
        let config = UIImage.SymbolConfiguration(pointSize: bounds.width * 0.3, weight: .medium)
        
        if currentProgress >= 1.0 {
            // Completed
            iconImageView.image = UIImage(systemName: "checkmark", withConfiguration: config)
            iconImageView.tintColor = progressColor
        } else if currentProgress > 0 {
            // Downloading
            iconImageView.image = UIImage(systemName: "arrow.down", withConfiguration: config)
            iconImageView.tintColor = progressColor
        } else {
            // Not started / Paused
            iconImageView.image = UIImage(systemName: "arrow.down.circle", withConfiguration: config)
            iconImageView.tintColor = .secondaryLabel
        }
    }
    
    private func pulseAnimation() {
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 1.15
        scaleAnimation.duration = 0.2
        scaleAnimation.autoreverses = true
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        layer.add(scaleAnimation, forKey: "pulseAnimation")
    }
    
    // MARK: - Convenience Methods
    
    /// Show indeterminate loading state
    func startIndeterminateAnimation() {
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.fromValue = 0
        rotationAnimation.toValue = CGFloat.pi * 2
        rotationAnimation.duration = 1.0
        rotationAnimation.repeatCount = .infinity
        
        progressLayer.strokeEnd = 0.3
        progressLayer.add(rotationAnimation, forKey: "rotationAnimation")
    }
    
    /// Stop indeterminate loading
    func stopIndeterminateAnimation() {
        progressLayer.removeAnimation(forKey: "rotationAnimation")
        progressLayer.strokeEnd = 0
    }
}

// MARK: - Preset Configurations
extension CircularProgressView {
    
    /// App Store download style (blue)
    static func appStoreStyle(size: CGFloat = 40) -> CircularProgressView {
        let view = CircularProgressView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        view.progressColor = .systemBlue
        view.trackColor = .systemGray5
        view.lineWidth = 3
        view.showIcon = true
        return view
    }
    
    /// Success style (green)
    static func successStyle(size: CGFloat = 40) -> CircularProgressView {
        let view = CircularProgressView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        view.progressColor = .systemGreen
        view.trackColor = .systemGray5
        view.lineWidth = 3
        view.showIcon = true
        return view
    }
    
    /// Accent style (purple)
    static func accentStyle(size: CGFloat = 40) -> CircularProgressView {
        let view = CircularProgressView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        view.progressColor = .systemPurple
        view.trackColor = .systemGray5
        view.lineWidth = 3
        view.showIcon = true
        return view
    }
    
    /// Minimal style (no icon, thin line)
    static func minimalStyle(size: CGFloat = 40) -> CircularProgressView {
        let view = CircularProgressView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        view.progressColor = .systemBlue
        view.trackColor = .systemGray6
        view.lineWidth = 2
        view.showIcon = false
        return view
    }
}
