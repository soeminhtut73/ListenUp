//
//  CircularProgressView.swift
//  ListenUp
//
//  Created by S M H  on 21/07/2025.
//

import Foundation
import UIKit

// MARK: - CircularProgressView
import UIKit

final class CircularProgressView: UIView {
    private let backgroundLayer = CAShapeLayer()
    private let progressLayer   = CAShapeLayer()

    // Public API: 0.0 ... 1.0
    func setProgress(_ value: Double, animated: Bool = true) {
        // Always update on main
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.setProgress(value, animated: animated) }
            return
        }

        // Clamp + monotonic (never go backwards)
        let clamped = CGFloat(max(0, min(1, value)))
        let shown   = (progressLayer.presentation()?.strokeEnd).map(CGFloat.init) ?? currentProgress
        let target  = max(clamped, shown, currentProgress)

        // Throttle UI updates (100ms) except final push
        let now = CACurrentMediaTime()
        pendingProgress = target
        if now - lastUpdateTime >= throttleInterval || target >= 0.999 {
            lastUpdateTime = now
            applyProgress(pendingProgress, animated: animated)
        }
    }

    // Optional: set once if server size unknown
    var isIndeterminate: Bool = false {
        didSet { isIndeterminate ? startSpinner() : stopSpinner() }
    }

    // Styling
    var lineWidth: CGFloat = 4 {
        didSet { backgroundLayer.lineWidth = lineWidth; progressLayer.lineWidth = lineWidth; setNeedsLayout() }
    }
    var trackColor: UIColor = .systemGray4 { didSet { backgroundLayer.strokeColor = trackColor.cgColor } }
    var progressColor: UIColor = .systemBlue { didSet { progressLayer.strokeColor = progressColor.cgColor } }

    // MARK: internals
    private var currentProgress: CGFloat = 0
    private var pendingProgress: CGFloat = 0
    private var lastUpdateTime: CFTimeInterval = 0
    private let throttleInterval: CFTimeInterval = 0.10
    private var spinnerLayer: CAShapeLayer?

    // Don’t expose a writable stored property that can bypass our clamp
    var progress: Double {
        get { Double(currentProgress) }
        set { setProgress(newValue, animated: false) }
    }

    override init(frame: CGRect) { super.init(frame: frame); commonSetup() }
    required init?(coder: NSCoder) { super.init(coder: coder); commonSetup() }

    private func commonSetup() {
        isOpaque = false

        backgroundLayer.lineWidth = lineWidth
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.strokeColor = trackColor.cgColor
        layer.addSublayer(backgroundLayer)

        progressLayer.lineWidth = lineWidth
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = progressColor.cgColor
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        layer.addSublayer(progressLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let start: CGFloat = -.pi / 2
        let end: CGFloat   = start + 2 * .pi
        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)

        backgroundLayer.path = path.cgPath
        progressLayer.path   = path.cgPath
    }

    private func applyProgress(_ to: CGFloat, animated: Bool) {
        let from = (progressLayer.presentation()?.strokeEnd).map(CGFloat.init) ?? currentProgress
        currentProgress = to

        // prevent animation stacking
        progressLayer.removeAnimation(forKey: "strokeEnd")

        if animated {
            let delta = abs(to - from)
            let duration = min(0.25, max(0.08, CFTimeInterval(delta) * 0.35))
            let anim = CABasicAnimation(keyPath: "strokeEnd")
            anim.fromValue = from
            anim.toValue   = to
            anim.duration  = duration
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            progressLayer.strokeEnd = to
            progressLayer.add(anim, forKey: "strokeEnd")
        } else {
            progressLayer.strokeEnd = to
        }
    }

    private func startSpinner() {
        progressLayer.isHidden = true
        if spinnerLayer == nil {
            let arc = CAShapeLayer()
            arc.fillColor = UIColor.clear.cgColor
            arc.strokeColor = progressColor.cgColor
            arc.lineWidth = lineWidth
            arc.lineCap = .round
            layer.addSublayer(arc)
            spinnerLayer = arc
        }
        let inset = lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let start: CGFloat = -.pi / 2
        let end: CGFloat   = start + .pi * 1.25
        spinnerLayer?.path = UIBezierPath(arcCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true).cgPath

        let rot = CABasicAnimation(keyPath: "transform.rotation")
        rot.fromValue = 0
        rot.toValue   = 2 * CGFloat.pi
        rot.duration  = 0.9
        rot.repeatCount = .infinity
        spinnerLayer?.add(rot, forKey: "spin")
    }

    private func stopSpinner() {
        spinnerLayer?.removeAllAnimations()
        spinnerLayer?.removeFromSuperlayer()
        spinnerLayer = nil
        progressLayer.isHidden = false
    }
    
    func reset() {
        // Main thread only for layer changes
        if !Thread.isMainThread { DispatchQueue.main.async { self.reset() }; return }
        
        pendingProgress = 0
        currentProgress = 0
        lastUpdateTime  = 0
        progressLayer.removeAllAnimations()
        progressLayer.strokeEnd = 0
        isIndeterminate = false
        }
}
