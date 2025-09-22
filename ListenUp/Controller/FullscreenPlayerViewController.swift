//
//  FullscreenPlayerViewController.swift
//  ListenUp
//
//  Created by S M H  on 22/09/2025.
//

import UIKit
import AVFoundation

final class FullscreenPlayerViewController: UIViewController {

    let playerView = PlayerView()
    private var player: AVPlayer { PlayerCenter.shared.player }

    // Call this to unhide the original videoView when dismissing
    var onDismiss: (() -> Void)?

    // UI
    private let playPauseButton = UIButton(type: .system)
    private let back15Button = UIButton(type: .system)
    private let fwd15Button = UIButton(type: .system)

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        configureAudioSession()

        // PlayerView
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        playerView.player = player
        playerView.playerLayer.videoGravity = .resizeAspect

        // Controls
        configureButtons()
        layoutControls()

        // Gestures
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(closePressed))
        swipe.direction = .down
        view.addGestureRecognizer(swipe)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func configureButtons() {
        func round(_ b: UIButton) {
            b.tintColor = .white
            b.backgroundColor = UIColor.black.withAlphaComponent(0.35)
            b.layer.cornerRadius = 24
            b.clipsToBounds = true
            b.contentEdgeInsets = .init(top: 10, left: 16, bottom: 10, right: 16)
        }

        playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)
        round(playPauseButton)

        back15Button.setImage(UIImage(systemName: "gobackward.15"), for: .normal)
        back15Button.addTarget(self, action: #selector(skipBack15), for: .touchUpInside)
        round(back15Button)

        fwd15Button.setImage(UIImage(systemName: "goforward.15"), for: .normal)
        fwd15Button.addTarget(self, action: #selector(skipFwd15), for: .touchUpInside)
        round(fwd15Button)
    }

    private func layoutControls() {
        [playPauseButton, back15Button, fwd15Button].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        // Transport centered bottom
        NSLayoutConstraint.activate([
            playPauseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playPauseButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            playPauseButton.widthAnchor.constraint(equalToConstant: 64),
            playPauseButton.heightAnchor.constraint(equalToConstant: 64),

            back15Button.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            back15Button.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -28),
            back15Button.widthAnchor.constraint(equalToConstant: 64),
            back15Button.heightAnchor.constraint(equalToConstant: 64),

            fwd15Button.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            fwd15Button.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 28),
            fwd15Button.widthAnchor.constraint(equalToConstant: 64),
            fwd15Button.heightAnchor.constraint(equalToConstant: 64),
        ])
    }
    
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

    // MARK: - Actions
    @objc private func closePressed() {
        dismiss(animated: true) { [weak self] in self?.onDismiss?() }
    }

    @objc private func togglePlayPause() {
        if player.timeControlStatus == .playing {
            player.pause()
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        } else {
            player.play()
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }

    @objc private func skipBack15()  { skip(by: -15) }
    @objc private func skipFwd15()   { skip(by:  15) }

    private func skip(by seconds: Double) {
        let cur = player.currentTime().seconds
        guard cur.isFinite else { return }
        let target = max(0, cur + seconds)
        let time = CMTime(seconds: target, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
}
