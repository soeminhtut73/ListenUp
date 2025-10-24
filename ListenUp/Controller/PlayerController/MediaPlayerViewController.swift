//
//  MediaPlayerViewController.swift
//  ListenUp
//
//  Created by S M H  on 15/09/2025.
//

import Foundation
import UIKit
import AVFoundation
import RealmSwift
import MediaPlayer

// MARK: - Models
struct MediaItem {
    let title: String
    let url: URL   // local file URL (Documents/… or elsewhere)
}

enum LoopMode { case off, one, all }

// MARK: - Media Player VC (Realm-aware)
final class MediaPlayerViewController: UIViewController {
    
    private let playerView = PlayerView()
    private var player = PlayerCenter.shared.player
    
    private var isVideoFullScreen = true
    private var videoFullConstraints: [NSLayoutConstraint] = []
    private var videoNormalConstraints: [NSLayoutConstraint] = []
    
    private let controlsStack = UIStackView()
    private let timeRowStack = UIStackView()
    private let transportStack = UIStackView()

    private var controlsOverlayConstraints: [NSLayoutConstraint] = []
    private var controlsBelowConstraints: [NSLayoutConstraint] = []

    // Optional gradient for readability in fullscreen
    private var fullscreenGradient: CAGradientLayer?
    
    // Inject your live Results before presenting
    var downloadsResults: Results<DownloadItem>!
    
    func startAt(url: URL?) {
        pendingStartURL = url
        if let url, let idx = playlist.firstIndex(where: { $0.url == url }) {
            currentIndex = idx
            startCurrent(replace: true)
            pendingStartURL = nil
        }
    }
    
    // UI
    private let closeButton = UIButton(type: .system)
    private let videoView = PlayerView()
    private let titleLabel = UILabel()
    private let slider = UISlider()
    private let currentLabel = UILabel()
    private let totalLabel = UILabel()
    private let prevButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let shuffleButton = UIButton(type: .system)
    private let loopButton = UIButton(type: .system)
    private let expandButton = UIButton(type: .system)
    private let skipForwardButton = UIButton(type: .system)
    private let skipBackwardButton = UIButton(type: .system)
    
    // Playback
    private var timeObs: Any?
    private var isSeeking = false
    
    // Playlist + observation
    private var token: NotificationToken?
    private var playlist: [MediaItem] = []
    private var currentIndex: Int = 0
    private var pendingStartURL: URL?   // set by startAt(url:)
    private var shuffleOn: Bool = false { didSet { updateShuffleUI() } }
    private var loopMode: LoopMode = .all { didSet { updateLoopUI() } }
    
    // Audio session observers
    private var interruptionObserver: Any?
    private var routeObserver: Any?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        videoView.player = player
        
        // IMPORTANT: Configure audio session for background playback
        configureAudioSession()
        
        setupUI()
        setupActions()
        wirePlayer()
        startObservingDownloads()   // builds playlist & starts playback
        startAudioSessionObservers()
        setupRemoteCommandCenter()
        observeBackgroundEvents()
        setupGesture()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fullscreenGradient?.frame = videoView.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    deinit {
        if let o = timeObs { player.removeTimeObserver(o) }
        NotificationCenter.default.removeObserver(self)
        token?.invalidate()
        
        // Clean up audio session observers
        if let obs = interruptionObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let obs = routeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
    
    // MARK: - Build playlist from Results
    private func buildItems(from results: Results<DownloadItem>) -> [MediaItem] {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Filter playable items (completed + has localPath)
        return results.compactMap { d -> MediaItem? in
            guard let rel = d.localPath, !rel.isEmpty else { return nil }
            guard d.status == .completed else { return nil }
            return MediaItem(title: d.title, url: docs.appendingPathComponent(rel))
        }
    }
    
    private func currentURL() -> URL? {
        return (player.currentItem?.asset as? AVURLAsset)?.url
    }
    
    // MARK: - Observe Realm live changes
    private func startObservingDownloads() {
        guard downloadsResults != nil else {
            assertionFailure("Set downloadsResults before presenting")
            return
        }
        
        token = downloadsResults.observe { [weak self] changes in
            guard let self = self else { return }
            let oldURL = self.currentURL() ?? self.pendingStartURL
            
            self.playlist = self.buildItems(from: self.downloadsResults)
            
            // Establish current index: prefer pendingStartURL (first time), else keep oldURL if it still exists.
            if let want = self.pendingStartURL, let idx = self.playlist.firstIndex(where: { $0.url == want }) {
                self.currentIndex = idx
                self.pendingStartURL = nil
                self.startCurrent(replace: true)
                return
            }
            
            // If the current URL still exists, keep the index; otherwise move sensibly
            if let old = oldURL, let idx = self.playlist.firstIndex(where: { $0.url == old }) {
                self.currentIndex = idx
                // same item; just refresh UI (in case title etc. changed)
                self.refreshUIForCurrent()
            } else {
                // Current item disappeared or first time; pick something reasonable
                if self.playlist.isEmpty {
                    self.player.replaceCurrentItem(with: nil)
                    self.updateUIEmpty()
                } else {
                    self.currentIndex = min(self.currentIndex, self.playlist.count - 1)
                    self.startCurrent(replace: true)
                }
            }
        }
    }
    
    // MARK: - UI
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Close Button
//        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
//        closeButton.tintColor = .white
//        closeButton.contentHorizontalAlignment = .fill
//        closeButton.contentVerticalAlignment = .fill
        
        // Video View - Fullscreen
        videoView.backgroundColor = .black
        videoView.playerLayer.videoGravity = .resizeAspectFill
        
        // Expand Button
        expandButton.setImage(UIImage(systemName: "arrow.down.right.and.arrow.up.left"), for: .normal)
        expandButton.tintColor = .white
        expandButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        expandButton.layer.cornerRadius = 18
        expandButton.addTarget(self, action: #selector(toggleVideoLayout), for: .touchUpInside)
        expandButton.clipsToBounds = true
        
        // Title Label
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1
        titleLabel.textAlignment = .center
        
        // Slider
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        slider.setThumbImage(createThumbImage(), for: .normal)
        
        // Time Labels
        currentLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        currentLabel.textColor = .white
        currentLabel.text = "0:00"
        
        totalLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        totalLabel.textColor = .white
        totalLabel.textAlignment = .right
        totalLabel.text = "0:00"
        
        // Transport Buttons - Smaller sizes
        prevButton.setImage(UIImage(systemName: "backward.fill"), for: .normal)
        prevButton.tintColor = .white
        prevButton.contentHorizontalAlignment = .fill
        prevButton.contentVerticalAlignment = .fill
        
        playPauseButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.contentHorizontalAlignment = .fill
        playPauseButton.contentVerticalAlignment = .fill
        
        nextButton.setImage(UIImage(systemName: "forward.fill"), for: .normal)
        nextButton.tintColor = .white
        nextButton.contentHorizontalAlignment = .fill
        nextButton.contentVerticalAlignment = .fill
        
        skipForwardButton.setImage(UIImage(systemName: "goforward.15"), for: .normal)
        skipForwardButton.tintColor = .white
        skipForwardButton.contentHorizontalAlignment = .fill
        skipForwardButton.contentVerticalAlignment = .fill
        
        skipBackwardButton.setImage(UIImage(systemName: "gobackward.15"), for: .normal)
        skipBackwardButton.tintColor = .white
        skipBackwardButton.contentHorizontalAlignment = .fill
        skipBackwardButton.contentVerticalAlignment = .fill
        
        // Option Buttons
        shuffleButton.setImage(UIImage(systemName: "shuffle"), for: .normal)
        shuffleButton.tintColor = .white
        shuffleButton.contentHorizontalAlignment = .fill
        shuffleButton.contentVerticalAlignment = .fill
        
        loopButton.setImage(UIImage(systemName: "repeat"), for: .normal)
        loopButton.tintColor = .white
        loopButton.contentHorizontalAlignment = .fill
        loopButton.contentVerticalAlignment = .fill
        
        [videoView, expandButton, titleLabel, slider,
         currentLabel, totalLabel, prevButton, playPauseButton,
         nextButton, shuffleButton, loopButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        let leftSpacer = UIView()
        let rightSpacer = UIView()
        
        transportStack.axis = .horizontal
        transportStack.alignment = .center
        transportStack.distribution = .equalSpacing
        transportStack.spacing = 0
        transportStack.translatesAutoresizingMaskIntoConstraints = false
        transportStack.addArrangedSubview(leftSpacer)
        transportStack.addArrangedSubview(skipBackwardButton)
        transportStack.addArrangedSubview(prevButton)
        transportStack.addArrangedSubview(playPauseButton)
        transportStack.addArrangedSubview(nextButton)
        transportStack.addArrangedSubview(skipForwardButton)
        transportStack.addArrangedSubview(rightSpacer)
        
        transportStack.setContentHuggingPriority(.required, for: .horizontal)
        transportStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            prevButton.widthAnchor.constraint(equalToConstant: 32),
            prevButton.heightAnchor.constraint(equalToConstant: 32),
            playPauseButton.widthAnchor.constraint(equalToConstant: 44),
            playPauseButton.heightAnchor.constraint(equalToConstant: 44),
            nextButton.widthAnchor.constraint(equalToConstant: 32),
            nextButton.heightAnchor.constraint(equalToConstant: 32),
            
            skipBackwardButton.widthAnchor.constraint(equalToConstant: 32),
            skipForwardButton.widthAnchor.constraint(equalToConstant: 32),
            
            leftSpacer.widthAnchor.constraint(equalToConstant: 10),
            rightSpacer.widthAnchor.constraint(equalToConstant: 10),
        ])
        
        timeRowStack.axis = .horizontal
        timeRowStack.alignment = .center
        timeRowStack.distribution = .fill
        timeRowStack.spacing = 8
        timeRowStack.translatesAutoresizingMaskIntoConstraints = false
        
        currentLabel.setContentHuggingPriority(.required, for: .horizontal)
        totalLabel.setContentHuggingPriority(.required, for: .horizontal)
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        timeRowStack.addArrangedSubview(currentLabel)
        timeRowStack.addArrangedSubview(slider)
        timeRowStack.addArrangedSubview(totalLabel)
        
        controlsStack.axis = .vertical
        controlsStack.alignment = .fill
        controlsStack.distribution = .fill
        controlsStack.spacing = 50
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.addArrangedSubview(titleLabel)
        controlsStack.addArrangedSubview(timeRowStack)
        controlsStack.addArrangedSubview(transportStack)
        view.addSubview(controlsStack)
        
        controlsOverlayConstraints = [
            controlsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            controlsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controlsStack.bottomAnchor.constraint(equalTo: shuffleButton.topAnchor, constant: -24)
        ]
        
        videoFullConstraints = [
            videoView.topAnchor.constraint(equalTo: view.topAnchor),
            videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ]
        
        videoNormalConstraints = [
            videoView.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            videoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoView.heightAnchor.constraint(equalTo: videoView.widthAnchor, multiplier: 9.0/16.0)
        ]
        
        // Controls below video (normal): place under videoView
        controlsBelowConstraints = [
            controlsStack.topAnchor.constraint(equalTo: view.centerYAnchor, constant: 20),
            controlsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            controlsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ]
        
        NSLayoutConstraint.activate([
//            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
//            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
//            closeButton.widthAnchor.constraint(equalToConstant: 32),
//            closeButton.heightAnchor.constraint(equalToConstant: 32),
            
            expandButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            expandButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            expandButton.widthAnchor.constraint(equalToConstant: 36),
            expandButton.heightAnchor.constraint(equalToConstant: 36),
            
            shuffleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            shuffleButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            shuffleButton.widthAnchor.constraint(equalToConstant: 28),
            shuffleButton.heightAnchor.constraint(equalToConstant: 28),
            
            loopButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            loopButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            loopButton.widthAnchor.constraint(equalToConstant: 28),
            loopButton.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        NSLayoutConstraint.activate(videoFullConstraints)
        NSLayoutConstraint.activate(controlsOverlayConstraints)
    }
    
    private func createThumbImage() -> UIImage? {
        let size = CGSize(width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.systemBlue.cgColor)
        context?.fillEllipse(in: CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    private func configure(button: UIButton, icon: String) {
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.tintColor = .white
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 20
    }
    
    private func setupActions() {
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        prevButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        
        skipForwardButton.addTarget(self, action: #selector(skipForward15Tapped), for: .touchUpInside)
        skipBackwardButton.addTarget(self, action: #selector(skipBack15Tapped), for: .touchUpInside)
        
        shuffleButton.addTarget(self, action: #selector(shuffleTapped), for: .touchUpInside)
        loopButton.addTarget(self, action: #selector(loopTapped), for: .touchUpInside)
        
        slider.addTarget(self, action: #selector(beginSeek), for: .touchDown)
        slider.addTarget(self, action: #selector(endSeek), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        slider.addTarget(self, action: #selector(seekChanged), for: .valueChanged)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(itemDidEnd(_:)),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: nil)
    }
    
    private func wirePlayer() {
        videoView.player = player
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObs = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] t in
            guard let self = self, !self.isSeeking else { return }
            let cur = t.seconds
            let total = self.player.currentItem?.duration.seconds ?? 0
            self.updateTimeUI(current: cur, total: total)
            self.refreshPlayIcon()
        }
    }
    
    private func observeBackgroundEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc private func appDidEnterBackground() {
        videoView.player = nil
    }
    
    @objc private func appWillEnterForeground() {
        videoView.player = PlayerCenter.shared.player
    }
    
    //MARK: - Setup Gesture
    private func setupGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        view.addGestureRecognizer(panGesture)
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .changed:
            // Only allow downward swipe
            if translation.y > 0 {
                view.transform = CGAffineTransform(translationX: 0, y: translation.y)
                
                // Add some opacity effect
                let progress = translation.y / view.frame.height
                view.alpha = 1.0 - (progress * 0.3)
            }
            
        case .ended, .cancelled:
            let shouldDismiss = translation.y > 100 || velocity.y > 500
            
            if shouldDismiss {
                // Dismiss and show mini player
                UIView.animate(withDuration: 0.3, animations: {
                    self.view.transform = CGAffineTransform(translationX: 0, y: self.view.frame.height)
                    self.view.alpha = 0
                }) { _ in
                    self.dismiss(animated: false) {
                        // Show mini player after dismissal
                        if let tabBarController = UIApplication.shared.rootTabBarController {
                            MiniPlayerContainerViewController.shared.show(in: tabBarController)
                        }
                    }
                }
            } else {
                // Snap back to original position
                UIView.animate(withDuration: 0.3) {
                    self.view.transform = .identity
                    self.view.alpha = 1.0
                }
            }
            
        default:
            break
        }
    }
    
    // MARK: - Start / Replace current item
    private func startCurrent(replace: Bool) {
        guard playlist.indices.contains(currentIndex) else { return }
        let item = playlist[currentIndex]
        titleLabel.text = item.title
        
        if replace {
            let currentURL = (PlayerCenter.shared.player.currentItem?.asset as? AVURLAsset)?.url
            if currentURL != item.url {
                PlayerCenter.shared.play(url: item.url)   // only replace if different
            } else {
                // same track already loaded → just ensure playback continues
                PlayerCenter.shared.player.play()
            }
        }
        
        refreshPlayIcon()
        updateLoopUI()
        Task {
            await updateDuration(item: item)
        }
    }
    
    func updateDuration(item: MediaItem) async {
        guard let currentItem = player.currentItem else { return }
        
        do {
            let duration = try await currentItem.asset.load(.duration)
            let total = duration.seconds
            
            PlayerCenter.shared.updateNowPlaying(title: item.title,
                                                 duration: total.isFinite ? total : 0,
                                                 isPlaying: true)
        } catch {
            print("Failed to load duration: \(error)")
            // Fallback to 0 duration
            PlayerCenter.shared.updateNowPlaying(title: item.title,
                                                 duration: 0,
                                                 isPlaying: true)
        }
    }
    
    private func refreshUIForCurrent() {
        guard playlist.indices.contains(currentIndex) else { return }
        titleLabel.text = playlist[currentIndex].title
        // slider/time labels will update as periodic time observer fires
    }
    
    private func updateUIEmpty() {
        titleLabel.text = "No items"
        slider.value = 0
        slider.maximumValue = 0
        currentLabel.text = "00:00"
        totalLabel.text = "00:00"
        refreshPlayIcon()
    }
    
    // MARK: - Controls
    
    @objc private func prevTapped() {
        guard !playlist.isEmpty else { return }
        if shuffleOn {
            currentIndex = Int.random(in: 0..<playlist.count)
        } else {
            currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
        }
        startCurrent(replace: true)
    }
    
    @objc private func nextTapped() {
        guard !playlist.isEmpty else { return }
        if shuffleOn {
            currentIndex = Int.random(in: 0..<playlist.count)
        } else {
            currentIndex = (currentIndex + 1) % playlist.count
        }
        startCurrent(replace: true)
    }
    
    @objc private func playPauseTapped() {
        if PlayerCenter.shared.isPlaying() {
            PlayerCenter.shared.pause()
        } else {
            if PlayerCenter.shared.player.currentItem != nil {
                PlayerCenter.shared.player.play()
            } else {
                startCurrent(replace: true)
            }
        }
        refreshPlayIcon()
    }
    
    @objc private func skipBack15Tapped() {
        PlayerCenter.shared.skipBackward15()
    }

    @objc private func skipForward15Tapped() {
        PlayerCenter.shared.skipForward15()
    }
    
    @objc private func toggleVideoLayout() {
        // Flip state
        isVideoFullScreen.toggle()
        
        if isVideoFullScreen {
            // Video: fullscreen
            NSLayoutConstraint.deactivate(videoNormalConstraints + controlsBelowConstraints)
            NSLayoutConstraint.activate(videoFullConstraints + controlsOverlayConstraints)
            videoView.playerLayer.videoGravity = .resizeAspectFill
            expandButton.setImage(UIImage(systemName: "arrow.down.right.and.arrow.up.left"), for: .normal)
            
            applyStyle(forFullScreen: true)
            addFullscreenGradientIfNeeded()
        } else {
            // Video: 16:9 header (normal)
            NSLayoutConstraint.deactivate(videoFullConstraints + controlsOverlayConstraints)
            NSLayoutConstraint.activate(videoNormalConstraints + controlsBelowConstraints)
            videoView.playerLayer.videoGravity = .resizeAspect
            expandButton.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right"), for: .normal)
            
            applyStyle(forFullScreen: false)
            removeFullscreenGradientIfNeeded()
        }
        
        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseInOut]) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func applyStyle(forFullScreen full: Bool) {
        if full {
            // White UI over video
            [titleLabel, currentLabel, totalLabel].forEach { $0.textColor = .white }
            [prevButton, skipForwardButton, skipBackwardButton, playPauseButton, nextButton, shuffleButton, loopButton, closeButton, expandButton]
                .forEach { $0.tintColor = .white }
            
            slider.minimumTrackTintColor = .white
            slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        } else {
            // Normal UI below video — use system colors
            [titleLabel, currentLabel, totalLabel].forEach { $0.textColor = .label }
            [prevButton, skipForwardButton, skipBackwardButton, playPauseButton, nextButton, shuffleButton, loopButton, closeButton, expandButton]
                .forEach { $0.tintColor = .label }
            
            slider.minimumTrackTintColor = .systemBlue // or .label if you prefer monochrome
            slider.maximumTrackTintColor = UIColor.label.withAlphaComponent(0.25)
        }
    }
    
    private func addFullscreenGradientIfNeeded() {
        guard fullscreenGradient == nil else { return }
        let g = CAGradientLayer()
        g.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.4).cgColor,
            UIColor.black.withAlphaComponent(0.6).cgColor
        ]
        g.locations = [0.0, 0.5, 1.0]
        g.startPoint = CGPoint(x: 0.5, y: 0.0)
        g.endPoint = CGPoint(x: 0.5, y: 1.0)
        g.frame = videoView.bounds
        g.name = "fullscreenGradient"
        videoView.layer.addSublayer(g)
        fullscreenGradient = g
    }
    
    private func removeFullscreenGradientIfNeeded() {
        fullscreenGradient?.removeFromSuperlayer()
        fullscreenGradient = nil
    }
    
    private func refreshPlayIcon() {
        let icon = (player.timeControlStatus == .playing) ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: icon), for: .normal)
    }
    
    // MARK: - Seek / time
    private func updateTimeUI(current: Double, total: Double) {
        let totalSafe = (total.isFinite && total > 0) ? total : 0
        currentLabel.text = formatTime(current)
        totalLabel.text = formatTime(totalSafe)
        slider.minimumValue = 0
        slider.maximumValue = Float(totalSafe)
        if !isSeeking { slider.value = Float(current) }
    }
    
    private func formatTime(_ t: Double) -> String {
        guard t.isFinite && t >= 0 else { return "00:00" }
        let s = Int(t)
        return String(format: "%02d:%02d", s/60, s%60)
    }
    
    @objc private func beginSeek() { isSeeking = true }
    
    @objc private func endSeek() {
        isSeeking = false
        let seconds = Double(slider.value)
        let cm = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    @objc private func seekChanged() {
        currentLabel.text = formatTime(Double(slider.value))
    }
    
    // MARK: - Shuffle / Loop
    @objc private func shuffleTapped() { shuffleOn.toggle() }
    private func updateShuffleUI() { shuffleButton.tintColor = shuffleOn ? .systemBlue : .label }
    
    @objc private func loopTapped() {
        switch loopMode {
        case .off: loopMode = .one
        case .one: loopMode = .all
        case .all: loopMode = .off
        }
    }
    private func updateLoopUI() {
        let icon = (loopMode == .one) ? "repeat.1" : "repeat"
        loopButton.setImage(UIImage(systemName: icon), for: .normal)
        loopButton.tintColor = (loopMode == .off) ? .label : .systemBlue
    }
    
    // MARK: - End-of-item handling
    @objc private func itemDidEnd(_ note: Notification) {
        guard note.object as? AVPlayerItem === player.currentItem else { return }
        switch loopMode {
        case .one:
            player.seek(to: .zero)
            player.play()
        case .all:
            nextTapped()
        case .off:
            refreshPlayIcon()
        }
    }
    
    // MARK: - Close
    @objc private func closeTapped() {
        dismiss(animated: true) {
            if let tabBarController = UIApplication.shared.rootTabBarController {
                MiniPlayerContainerViewController.shared.show(in: tabBarController)
            }
        }
    }
    
    // MARK: - Background Audio Setup (CRITICAL FOR BACKGROUND PLAYBACK)
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Use .playback category for background audio
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            print("Audio session configured for background playback")
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    // MARK: - Audio Session Observers
    private func startAudioSessionObservers() {
        let nc = NotificationCenter.default
        
        // Handle interruptions (phone calls, etc.)
        interruptionObserver = nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            guard let typeRaw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
            
            switch type {
            case .began:
                // Interruption began - pause playback
                self.player.pause()
                self.updateNowPlayingPlaybackRate(0.0)
            case .ended:
                // Interruption ended - check if we should resume
                let shouldResume = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt)
                    .flatMap(AVAudioSession.InterruptionOptions.init(rawValue:))?
                    .contains(.shouldResume) ?? false
                if shouldResume {
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        self.player.play()
                        self.updateNowPlayingPlaybackRate(1.0)
                    } catch {
                        print("Failed to reactivate audio session: \(error)")
                    }
                }
            @unknown default: break
            }
        }
        
        // Handle route changes (headphone disconnect, etc.)
        routeObserver = nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            if let reasonRaw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
               let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw),
               reason == .oldDeviceUnavailable {
                // Headphones disconnected - pause playback
                self.player.pause()
                self.updateNowPlayingPlaybackRate(0.0)
            }
        }
    }
    
    // MARK: - Remote Command Center Setup
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if !self.playlist.isEmpty {
                self.player.play()
                self.updateNowPlayingPlaybackRate(1.0)
                return .success
            }
            return .commandFailed
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.player.pause()
            self.updateNowPlayingPlaybackRate(0.0)
            return .success
        }
        
        // Next track command
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.nextTapped()
            return .success
        }
        
        // Previous track command
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.prevTapped()
            return .success
        }
        
        
        
        // Change playback position command (scrubbing)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self else { return .commandFailed }
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                let time = CMTime(seconds: event.positionTime, preferredTimescale: 600)
                self.player.seek(to: time)
                return .success
            }
            return .commandFailed
        }
    }
    
    // Helper to update Now Playing info center
    private func updateNowPlayingPlaybackRate(_ rate: Float) {
        if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            info[MPNowPlayingInfoPropertyPlaybackRate] = rate
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
}
