//
//  QuickLandscapePlayerViewController.swift
//  ListenUp
//
//  Created by S M H  on 28/10/2025.
//

import UIKit
import AVFoundation

final class QuickLandscapePlayerViewController: UIViewController {
    
    private let player: AVPlayer
    private let onDismiss: (() -> Void)?
    
    private let playerView = PlayerView()
    private let controlsContainer = UIView()
    private let skipBack = UIButton(type: .system)
    private let skipFwd  = UIButton(type: .system)
    private let slider   = UISlider()
    
    private var hideTimer: Timer?
    private var timeObs: Any?
    
    init(player: AVPlayer, onDismiss: (() -> Void)? = nil) {
        self.player = player
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    // Force landscape
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        // Player layer
        playerView.player = player
        playerView.playerLayer.videoGravity = .resizeAspect
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Controls container
        controlsContainer.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        controlsContainer.layer.cornerRadius = 14
        controlsContainer.clipsToBounds = true
        view.addSubview(controlsContainer)
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Buttons
        let iconCfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
        skipBack.setImage(UIImage(systemName: "gobackward.15", withConfiguration: iconCfg), for: .normal)
        skipFwd.setImage(UIImage(systemName: "goforward.15",  withConfiguration: iconCfg), for: .normal)
        [skipBack, skipFwd].forEach { btn in
            btn.tintColor = .white
//            btn.backgroundColor = UIColor.black.withAlphaComponent(0.35)
            btn.layer.cornerRadius = 24
            btn.translatesAutoresizingMaskIntoConstraints = false
        }
        
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        slider.translatesAutoresizingMaskIntoConstraints = false
        
        controlsContainer.addSubview(skipBack)
        controlsContainer.addSubview(slider)
        controlsContainer.addSubview(skipFwd)
        
        NSLayoutConstraint.activate([
            controlsContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            controlsContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 64),
            
            // Left button
            skipBack.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 12),
            skipBack.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 8),
            skipBack.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -8),
            skipBack.widthAnchor.constraint(equalToConstant: 48),
            
            // Slider
            slider.leadingAnchor.constraint(equalTo: skipBack.trailingAnchor, constant: 12),
            slider.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 12),
            slider.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -12),
            slider.widthAnchor.constraint(greaterThanOrEqualToConstant: 520),
            
            // Right button
            skipFwd.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 12),
            skipFwd.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -12),
            skipFwd.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 8),
            skipFwd.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -8),
            skipFwd.widthAnchor.constraint(equalToConstant: 48)
        ])
        
        // Make sure controls sit above the video layer
        view.bringSubviewToFront(controlsContainer)
        
        skipBack.addTarget(self, action: #selector(skipBack15), for: .touchUpInside)
        skipFwd.addTarget(self, action: #selector(skipFwd15), for: .touchUpInside)
        slider.addTarget(self, action: #selector(sliderBegan), for: .touchDown)
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        // Auto-hide controls
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
        view.addGestureRecognizer(tap)
        scheduleAutoHide()
        
        // Pan to dismiss
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(pan)
        
        // Time observer for slider
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObs = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] t in
            guard let self = self else { return }
            self.refreshSlider()
        }
        
        refreshSlider()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showControls(animated: true)
    }
    
    deinit {
        if let o = timeObs { player.removeTimeObserver(o) }
        hideTimer?.invalidate()
    }
    
    // MARK: Controls show/hide
    private func scheduleAutoHide() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.hideControls(animated: true)
        }
    }
    
    @objc private func toggleControls() {
        let hidden = controlsContainer.alpha < 0.5
        if hidden { showControls(animated: true) } else { hideControls(animated: true) }
    }
    
    private func showControls(animated: Bool) {
        hideTimer?.invalidate()
        let work = { self.controlsContainer.alpha = 1 }
        if animated { UIView.animate(withDuration: 0.2, animations: work) } else { work() }
        scheduleAutoHide()
    }
    
    private func hideControls(animated: Bool) {
        let work = { self.controlsContainer.alpha = 0 }
        if animated { UIView.animate(withDuration: 0.25, animations: work) } else { work() }
    }
    
    // MARK: Slider
    private var isScrubbing = false
    
    private func refreshSlider() {
        guard !isScrubbing else { return }
        let cur = player.currentTime().seconds
        let dur = player.currentItem?.duration.seconds ?? 0
        if dur.isFinite && dur > 0 {
            slider.minimumValue = 0
            slider.maximumValue = Float(dur)
            slider.value = Float(cur)
        } else {
            slider.minimumValue = 0
            slider.maximumValue = 1
            slider.value = 0
        }
    }
    
    @objc private func sliderBegan() {
        isScrubbing = true
        showControls(animated: true)
    }
    
    @objc private func sliderChanged() {
        showControls(animated: false)
    }
    
    @objc private func sliderEnded() {
        let seconds = Double(slider.value)
        let t = CMTime(seconds: seconds, preferredTimescale: 600)
        let wasPlaying = (player.timeControlStatus == .playing)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self = self else { return }
            self.isScrubbing = false
            if wasPlaying { self.player.play() }
            self.scheduleAutoHide()
        }
    }
    
    // MARK: Skip
    @objc private func skipBack15() { seek(by: -15) }
    @objc private func skipFwd15()  { seek(by:  15) }
    
    private func seek(by delta: Double) {
        guard let item = player.currentItem else { return }
        let cur = player.currentTime().seconds
        let dur = item.duration.seconds
        var target = cur + delta
        if dur.isFinite { target = max(0, min(target, max(0, dur - 0.01))) } else { target = max(0, target) }
        let t = CMTime(seconds: target, preferredTimescale: 600)
        let wasPlaying = (player.timeControlStatus == .playing)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            if wasPlaying { self?.player.play() }
        }
        showControls(animated: true) // also resets auto-hide
    }
    
    // MARK: Pan to dismiss (expand/collapse feel)
    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: view)
        let progress = max(0, t.y / view.bounds.height)
        switch g.state {
        case .changed:
            let scale = 1 - 0.05 * progress
            view.transform = CGAffineTransform(translationX: 0, y: t.y).scaledBy(x: scale, y: scale)
            view.alpha = 1 - 0.3 * progress
        case .ended, .cancelled:
            let v = g.velocity(in: view).y
            if progress > 0.28 || v > 800 {
                dismiss(animated: true) { [weak self] in self?.onDismiss?() }
            } else {
                UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) {
                    self.view.transform = .identity
                    self.view.alpha = 1
                }
            }
        default: break
        }
    }
    
    // Dismiss on tap outside controls (handled by toggleControls); ensure callback fires
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.isBeingDismissed || self.isMovingFromParent { onDismiss?() }
    }
}
