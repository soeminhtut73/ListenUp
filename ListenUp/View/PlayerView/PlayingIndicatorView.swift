import UIKit

final class PlayingIndicatorView: UIView {
    private var isAnimating = false
    private let replicator = CAReplicatorLayer()
    private let bar = CALayer()
    private let animationKey = "eq-bounce"
    
    // MARK: - Customization Properties
    var barColor: UIColor = .systemBlue {
        didSet { updateBarColor() }
    }
    
    var barCount: Int = 3 {
        didSet { replicator.instanceCount = barCount }
    }
    
    var animationSpeed: Double = 0.8
    
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
        
        // Add subtle background circle
        layer.cornerRadius = 2
        backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        
        layer.addSublayer(replicator)
        replicator.instanceCount = barCount
        replicator.instanceDelay = 0.1
        
        // Enhanced bar with gradient effect
        bar.backgroundColor = barColor.cgColor
        bar.cornerRadius = 2
        bar.masksToBounds = true
        
        // Add subtle shadow for depth
        bar.shadowColor = barColor.cgColor
        bar.shadowOpacity = 0.3
        bar.shadowOffset = CGSize(width: 0, height: 1)
        bar.shadowRadius = 2
        
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
        
        // Center the replicator
        let contentWidth = bounds.width * 0.6
        let contentHeight = bounds.height * 0.65
        let offsetX = (bounds.width - contentWidth) / 2
        let offsetY = (bounds.height - contentHeight) / 2
        
        replicator.frame = CGRect(
            x: offsetX,
            y: offsetY,
            width: contentWidth,
            height: contentHeight
        )
        
        // Bar sizing
        let barWidth = max(3, contentWidth / CGFloat(barCount * 2))
        let maxBarHeight = contentHeight
        
        bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: maxBarHeight)
        bar.position = CGPoint(x: barWidth/2, y: contentHeight)
        bar.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        bar.cornerRadius = barWidth / 2
        
        // Spacing between bars
        let totalSpacing = contentWidth - (barWidth * CGFloat(barCount))
        let spacing = totalSpacing / CGFloat(barCount - 1) + barWidth
        replicator.instanceTransform = CATransform3DMakeTranslation(spacing, 0, 0)
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        ensureRunningIfNeeded()
    }
    
    // MARK: - Public Methods
    func start() {
        guard !isAnimating else { return }
        isAnimating = true
        
        // Create more dynamic animation
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale.y")
        scaleAnimation.fromValue = 0.25
        scaleAnimation.toValue = 1.0
        scaleAnimation.duration = animationSpeed
        scaleAnimation.autoreverses = true
        scaleAnimation.repeatCount = .infinity
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // Add subtle opacity variation
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.6
        opacityAnimation.toValue = 1.0
        opacityAnimation.duration = animationSpeed
        opacityAnimation.autoreverses = true
        opacityAnimation.repeatCount = .infinity
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        let group = CAAnimationGroup()
        group.animations = [scaleAnimation, opacityAnimation]
        group.duration = animationSpeed
        group.autoreverses = true
        group.repeatCount = .infinity
        
        bar.add(group, forKey: animationKey)
    }
    
    func stop() {
        isAnimating = false
        bar.removeAllAnimations()
    }
    
    // MARK: - Private Methods
    private func updateBarColor() {
        bar.backgroundColor = barColor.cgColor
        bar.shadowColor = barColor.cgColor
        backgroundColor = barColor.withAlphaComponent(0.12)
    }
    
    private func ensureRunningIfNeeded() {
        guard isAnimating, window != nil else { return }
        if bar.animation(forKey: animationKey) == nil {
            start()
        }
    }
    
    @objc private func appDidBecomeActive() {
        ensureRunningIfNeeded()
    }
}

// MARK: - Convenience Styles
extension PlayingIndicatorView {
    /// Classic blue style
    static func blueStyle() -> PlayingIndicatorView {
        let view = PlayingIndicatorView()
        view.barColor = .systemBlue
        view.barCount = 3
        view.animationSpeed = 0.55
        return view
    }
    
    /// Minimal white style (for dark backgrounds)
    static func lightStyle() -> PlayingIndicatorView {
        let view = PlayingIndicatorView()
        view.barColor = .white
        view.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        view.barCount = 3
        view.animationSpeed = 0.5
        return view
    }
    
    /// Vibrant gradient style
    static func vibrantStyle() -> PlayingIndicatorView {
        let view = PlayingIndicatorView()
        view.barColor = .systemPink
        view.barCount = 4
        view.animationSpeed = 0.45
        return view
    }
    
    /// Minimal label color (adapts to light/dark mode)
    static func adaptiveStyle() -> PlayingIndicatorView {
        let view = PlayingIndicatorView()
        view.barColor = .label
        view.backgroundColor = UIColor.secondarySystemBackground
        view.barCount = 3
        view.animationSpeed = 0.55
        return view
    }
}
