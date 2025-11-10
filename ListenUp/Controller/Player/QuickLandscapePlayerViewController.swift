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
    
    // Center controls
    private let centerControlsContainer = UIView()
    private let skipBackButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let skipForwardButton = UIButton(type: .system)
    
    // Bottom controls
    private let bottomControlsContainer = UIView()
    private let slider = UISlider()
    private let currentTimeLabel = UILabel()
    private let totalTimeLabel = UILabel()
    
    private var hideTimer: Timer?
    private var timeObs: Any?
    private var isScrubbing = false
    
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
        
        setupPlayerView()
        setupCenterControls()
        setupBottomControls()
        setupGestures()
        setupTimeObserver()
        
        // Observe player status
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showControls(animated: true)
        updatePlayPauseButton()
    }
    
    deinit {
        if let o = timeObs { player.removeTimeObserver(o) }
        hideTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup UI
    
    private func setupPlayerView() {
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
    }
    
    private func setupCenterControls() {
        centerControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(centerControlsContainer)
        
        // Configure buttons
        let iconSize: CGFloat = 32
        let buttonSize: CGFloat = 70
        
        // Skip back button
        let backConfig = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
        skipBackButton.setImage(UIImage(systemName: "gobackward.15", withConfiguration: backConfig), for: .normal)
        skipBackButton.tintColor = .white
        skipBackButton.layer.cornerRadius = buttonSize / 2
        skipBackButton.translatesAutoresizingMaskIntoConstraints = false
        skipBackButton.addTarget(self, action: #selector(skipBack15), for: .touchUpInside)
        
        // Play/Pause button (larger)
        let playConfig = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)
        playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: playConfig), for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.layer.cornerRadius = 45
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)
        
        // Skip forward button
        let forwardConfig = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
        skipForwardButton.setImage(UIImage(systemName: "goforward.15", withConfiguration: forwardConfig), for: .normal)
        skipForwardButton.tintColor = .white
        skipForwardButton.layer.cornerRadius = buttonSize / 2
        skipForwardButton.translatesAutoresizingMaskIntoConstraints = false
        skipForwardButton.addTarget(self, action: #selector(skipFwd15), for: .touchUpInside)
        
        centerControlsContainer.addSubview(skipBackButton)
        centerControlsContainer.addSubview(playPauseButton)
        centerControlsContainer.addSubview(skipForwardButton)
        
        NSLayoutConstraint.activate([
            // Container center
            centerControlsContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerControlsContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Play/Pause button (center)
            playPauseButton.centerXAnchor.constraint(equalTo: centerControlsContainer.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: centerControlsContainer.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 90),
            playPauseButton.heightAnchor.constraint(equalToConstant: 90),
            
            // Skip back button (left)
            skipBackButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -40),
            skipBackButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            skipBackButton.widthAnchor.constraint(equalToConstant: buttonSize),
            skipBackButton.heightAnchor.constraint(equalToConstant: buttonSize),
            
            // Skip forward button (right)
            skipForwardButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 40),
            skipForwardButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            skipForwardButton.widthAnchor.constraint(equalToConstant: buttonSize),
            skipForwardButton.heightAnchor.constraint(equalToConstant: buttonSize),
            
            // Container bounds
            centerControlsContainer.topAnchor.constraint(equalTo: skipBackButton.topAnchor),
            centerControlsContainer.leadingAnchor.constraint(equalTo: skipBackButton.leadingAnchor),
            centerControlsContainer.trailingAnchor.constraint(equalTo: skipForwardButton.trailingAnchor),
            centerControlsContainer.bottomAnchor.constraint(equalTo: skipBackButton.bottomAnchor)
        ])
    }
    
    private func setupBottomControls() {
        bottomControlsContainer.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        bottomControlsContainer.layer.cornerRadius = 8
        bottomControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomControlsContainer)
        
        // Time labels
        currentTimeLabel.text = "0:00"
        currentTimeLabel.textColor = .white
        currentTimeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        totalTimeLabel.text = "0:00"
        totalTimeLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        totalTimeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        totalTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Slider
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action: #selector(sliderBegan), for: .touchDown)
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        bottomControlsContainer.addSubview(currentTimeLabel)
        bottomControlsContainer.addSubview(slider)
        bottomControlsContainer.addSubview(totalTimeLabel)
        
        NSLayoutConstraint.activate([
            // Bottom container
            bottomControlsContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            bottomControlsContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            bottomControlsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            bottomControlsContainer.heightAnchor.constraint(equalToConstant: 60),
            
            // Current time label
            currentTimeLabel.leadingAnchor.constraint(equalTo: bottomControlsContainer.leadingAnchor, constant: 16),
            currentTimeLabel.centerYAnchor.constraint(equalTo: bottomControlsContainer.centerYAnchor),
            currentTimeLabel.widthAnchor.constraint(equalToConstant: 50),
            
            // Slider
            slider.leadingAnchor.constraint(equalTo: currentTimeLabel.trailingAnchor, constant: 12),
            slider.trailingAnchor.constraint(equalTo: totalTimeLabel.leadingAnchor, constant: -12),
            slider.centerYAnchor.constraint(equalTo: bottomControlsContainer.centerYAnchor),
            
            // Total time label
            totalTimeLabel.trailingAnchor.constraint(equalTo: bottomControlsContainer.trailingAnchor, constant: -16),
            totalTimeLabel.centerYAnchor.constraint(equalTo: bottomControlsContainer.centerYAnchor),
            totalTimeLabel.widthAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupGestures() {
        // Tap to toggle controls
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
        view.addGestureRecognizer(tap)
        
        // Pan to dismiss
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(pan)
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObs = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.updateTimeLabelsAndSlider()
            self.updatePlayPauseButton()
        }
    }
    
    // MARK: - Controls Show/Hide
    
    private func scheduleAutoHide() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.hideControls(animated: true)
        }
    }
    
    @objc private func toggleControls() {
        let hidden = centerControlsContainer.alpha < 0.5
        if hidden {
            showControls(animated: true)
        } else {
            hideControls(animated: true)
        }
    }
    
    private func showControls(animated: Bool) {
        hideTimer?.invalidate()
        let work = {
            self.centerControlsContainer.alpha = 1
            self.bottomControlsContainer.alpha = 1
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: work)
        } else {
            work()
        }
        scheduleAutoHide()
    }
    
    private func hideControls(animated: Bool) {
        let work = {
            self.centerControlsContainer.alpha = 0
            self.bottomControlsContainer.alpha = 0
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: work)
        } else {
            work()
        }
    }
    
    // MARK: - Time Display
    
    private func updateTimeLabelsAndSlider() {
        guard !isScrubbing else { return }
        
        let currentSeconds = player.currentTime().seconds
        let duration = player.currentItem?.duration.seconds ?? 0
        
        if duration.isFinite && duration > 0 {
            currentTimeLabel.text = formatTime(currentSeconds)
            totalTimeLabel.text = formatTime(duration)
            
            slider.minimumValue = 0
            slider.maximumValue = Float(duration)
            slider.value = Float(currentSeconds)
        } else {
            currentTimeLabel.text = "0:00"
            totalTimeLabel.text = "0:00"
            slider.minimumValue = 0
            slider.maximumValue = 1
            slider.value = 0
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    // MARK: - Player Controls
    
    @objc private func togglePlayPause() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
        updatePlayPauseButton()
        showControls(animated: true)
    }
    
    private func updatePlayPauseButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)
        let isPlaying = player.timeControlStatus == .playing
        let imageName = isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
    }
    
    @objc private func skipBack15() {
        PlayerCenter.shared.seek(by: -15)
        showControls(animated: true)
    }
    
    @objc private func skipFwd15() {
        PlayerCenter.shared.seek(by: 15)
        showControls(animated: true)
    }
    
    @objc private func playerDidFinishPlaying() {
        updatePlayPauseButton()
    }
    
    // MARK: - Slider
    
    @objc private func sliderBegan() {
        isScrubbing = true
        showControls(animated: true)
    }
    
    @objc private func sliderChanged() {
        let seconds = Double(slider.value)
        currentTimeLabel.text = formatTime(seconds)
        showControls(animated: false)
    }
    
    @objc private func sliderEnded() {
        let seconds = Double(slider.value)
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        let wasPlaying = (player.timeControlStatus == .playing)
        
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self = self else { return }
            self.isScrubbing = false
            if wasPlaying {
                self.player.play()
            }
            self.scheduleAutoHide()
        }
    }
    
    // MARK: - Pan to Dismiss
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let progress = max(0, translation.y / view.bounds.height)
        
        switch gesture.state {
        case .changed:
            let scale = 1 - 0.05 * progress
            view.transform = CGAffineTransform(translationX: 0, y: translation.y)
                .scaledBy(x: scale, y: scale)
            view.alpha = 1 - 0.3 * progress
            
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view).y
            if progress > 0.28 || velocity > 800 {
                dismiss(animated: true) { [weak self] in
                    self?.onDismiss?()
                }
            } else {
                UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) {
                    self.view.transform = .identity
                    self.view.alpha = 1
                }
            }
            
        default:
            break
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.isBeingDismissed || self.isMovingFromParent {
            onDismiss?()
        }
    }
}
