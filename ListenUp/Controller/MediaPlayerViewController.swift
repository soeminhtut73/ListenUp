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

    // Inject your live Results before presenting
    var downloadsResults: Results<DownloadItem>!

    // Optionally tell player which file to start at (call after present)
    func startAt(url: URL?) {
        pendingStartURL = url
        // If the playlist is already built, jump right now.
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
        guard playlist.indices.contains(currentIndex) else { return nil }
        return playlist[currentIndex].url
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

        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .label

        videoView.player = player
        videoView.playerLayer.videoGravity = .resizeAspect

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center

        currentLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        totalLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        currentLabel.text = "00:00"
        totalLabel.text = "00:00"
        
        expandButton.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right"), for: .normal)
        expandButton.tintColor = .white
        expandButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        expandButton.layer.cornerRadius = 16
        expandButton.clipsToBounds = true

        configure(button: prevButton, icon: "backward.fill")
        configure(button: playPauseButton, icon: "play.fill")
        configure(button: nextButton, icon: "forward.fill")
        configure(button: shuffleButton, icon: "shuffle")
        configure(button: loopButton, icon: "repeat")

        // Layout
        [closeButton, videoView, titleLabel, slider, currentLabel, totalLabel,
         prevButton, playPauseButton, nextButton, shuffleButton, loopButton, expandButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        let transport = UIStackView(arrangedSubviews: [prevButton, playPauseButton, nextButton])
        transport.axis = .horizontal
        transport.alignment = .center
        transport.spacing = 28
        transport.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(transport)

        let options = UIStackView(arrangedSubviews: [shuffleButton, loopButton])
        options.axis = .horizontal
        options.alignment = .center
        options.spacing = 24
        options.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(options)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            
            expandButton.topAnchor.constraint(equalTo: videoView.topAnchor, constant: 8),
            expandButton.trailingAnchor.constraint(equalTo: videoView.trailingAnchor, constant: -8),
            expandButton.widthAnchor.constraint(equalToConstant: 32),
            expandButton.heightAnchor.constraint(equalToConstant: 32),

            // Centered video, 9:16 ratio
            videoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            videoView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 100),
            videoView.widthAnchor.constraint(equalTo: view.widthAnchor),
            videoView.heightAnchor.constraint(equalTo: videoView.widthAnchor, multiplier: 9.0/16.0),

            titleLabel.topAnchor.constraint(equalTo: videoView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            slider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            currentLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 4),
            currentLabel.leadingAnchor.constraint(equalTo: slider.leadingAnchor),

            totalLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 4),
            totalLabel.trailingAnchor.constraint(equalTo: slider.trailingAnchor),

            transport.topAnchor.constraint(equalTo: currentLabel.bottomAnchor, constant: 16),
            transport.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            options.topAnchor.constraint(equalTo: transport.bottomAnchor, constant: 16),
            options.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func configure(button: UIButton, icon: String) {
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.tintColor = .label
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 20
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
    }

    private func setupActions() {
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        expandButton.addTarget(self, action: #selector(expandTapped), for: .touchUpInside)

        prevButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

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
        // Optional: Hide video if needed
//        playerView.isHidden = true
        videoView.player = nil
    }
    
    @objc private func appWillEnterForeground() {
//        playerView.isHidden = false
        videoView.player = PlayerCenter.shared.player
    }

    // MARK: - Start / Replace current item
    private func startCurrent(replace: Bool) {
        guard playlist.indices.contains(currentIndex) else { return }
        let item = playlist[currentIndex]
        titleLabel.text = item.title

        if replace {
            PlayerCenter.shared.play(url: item.url)
        }
        refreshPlayIcon()
        updateLoopUI()
        
        // Update now playing
        let total = player.currentItem?.asset.duration.seconds ?? 0
        PlayerCenter.shared.updateNowPlaying(title: item.title, duration: total.isFinite ? total : 0, isPlaying: true)
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
    @objc private func expandTapped() {
        let full = FullscreenPlayerViewController()
        full.modalPresentationStyle = .fullScreen
        // Hide the inline video while fullscreen is up to avoid double-rendering
//        self.videoView.isHidden = true
        full.onDismiss = { [weak self] in
//            self?.videoView.isHidden = false
        }
        present(full, animated: true)
    }
    
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
            // Resume the current item. If you track the current URL, reuse it:
            guard playlist.indices.contains(currentIndex) else { return }
            let item = playlist[currentIndex]
            PlayerCenter.shared.play(url: item.url)
        }
        refreshPlayIcon()
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
        dismiss(animated: true)
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
