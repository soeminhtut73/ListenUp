//
//  MiniPlayerContainerViewController.swift
//  ListenUp
//
//  Created by S M H  on 23/09/2025.
//

import UIKit
import AVFoundation
import MediaPlayer
import RealmSwift

// MARK: - MiniPlayerContainerViewController

class MiniPlayerContainerViewController: UIViewController {
    
    // MARK: - Singleton
    
    static let shared = MiniPlayerContainerViewController()
    
    // MARK: - Properties
    
    private var miniPlayerView: MiniPlayerView?
    private var miniPlayerBottomConstraint: NSLayoutConstraint?
    private var timeObserver: Any?
    
    private let miniPlayerHeight: CGFloat = 65
    private var isShowing = false
    
    // MARK: - Realm Access
    
    private var realm: Realm? {
        return try? Realm()
    }
    
    private var downloadsResults: Results<DownloadItem>? {
        return RealmService.shared.fetchAllMedia()
            .sorted(byKeyPath: "createdAt", ascending: false)
    }
    
    // MARK: - Initialization
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stopObservingPlayer()
    }
    
    // MARK: - Show/Hide
    
    func show(in tabBarController: UITabBarController, animated: Bool = true) {
        guard !isShowing else { return }
        isShowing = true
        
        // Create mini player
        let miniPlayer = createMiniPlayer()
        miniPlayer.alpha = animated ? 0 : 1
        tabBarController.view.addSubview(miniPlayer)
        
        // Setup constraints
        let bottomConstraint = setupConstraints(
            for: miniPlayer,
            in: tabBarController,
            initialOffset: animated ? miniPlayerHeight : 0
        )
        
        self.miniPlayerView = miniPlayer
        self.miniPlayerBottomConstraint = bottomConstraint
        
        // Configure actions
        configureMiniPlayerActions()
        
        // Start observing
        startObservingPlayer()
        
        // Adjust tab bar
        tabBarController.adjustForMiniPlayer(height: miniPlayerHeight, animated: animated)
        
        // Animate in
        if animated {
            animateShow(in: tabBarController, bottomConstraint: bottomConstraint, miniPlayer: miniPlayer)
        } else {
            bottomConstraint.constant = 0
        }
    }
    
    func hide(animated: Bool = true) {
        guard isShowing, let miniPlayerView = miniPlayerView else { return }
        isShowing = false
        
        // Adjust tab bar
        if let tabBarController = miniPlayerView.window?.rootViewController as? UITabBarController {
            tabBarController.adjustForMiniPlayer(height: 0, animated: animated)
        }
        
        // Animate or immediate hide
        if animated {
            animateHide(miniPlayerView: miniPlayerView)
        } else {
            removeMiniPlayer()
        }
    }
    
    // MARK: - Setup
    
    private func createMiniPlayer() -> MiniPlayerView {
        let miniPlayer = MiniPlayerView()
        miniPlayer.translatesAutoresizingMaskIntoConstraints = false
        return miniPlayer
    }
    
    private func setupConstraints(
        for miniPlayer: MiniPlayerView,
        in tabBarController: UITabBarController,
        initialOffset: CGFloat
    ) -> NSLayoutConstraint {
        let bottomConstraint = miniPlayer.bottomAnchor.constraint(
            equalTo: tabBarController.tabBar.topAnchor,
            constant: initialOffset
        )
        
        NSLayoutConstraint.activate([
            miniPlayer.leadingAnchor.constraint(equalTo: tabBarController.view.leadingAnchor),
            miniPlayer.trailingAnchor.constraint(equalTo: tabBarController.view.trailingAnchor),
            miniPlayer.heightAnchor.constraint(equalToConstant: miniPlayerHeight),
            bottomConstraint
        ])
        
        return bottomConstraint
    }
    
    private func configureMiniPlayerActions() {
        miniPlayerView?.onTap = { [weak self] in
            self?.expandToFullPlayer()
        }
        
        miniPlayerView?.onPlayPause = { [weak self] in
            self?.togglePlayPause()
        }
    }
    
    // MARK: - Animations
    
    private func animateShow(
        in tabBarController: UITabBarController,
        bottomConstraint: NSLayoutConstraint,
        miniPlayer: MiniPlayerView
    ) {
        tabBarController.view.layoutIfNeeded()
        
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: .curveEaseOut,
            animations: {
                bottomConstraint.constant = 0
                miniPlayer.alpha = 1
                tabBarController.view.layoutIfNeeded()
            }
        )
    }
    
    private func animateHide(miniPlayerView: MiniPlayerView) {
        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.miniPlayerBottomConstraint?.constant = self.miniPlayerHeight
                miniPlayerView.alpha = 0
                miniPlayerView.superview?.layoutIfNeeded()
            },
            completion: { _ in
                self.removeMiniPlayer()
            }
        )
    }
    
    private func removeMiniPlayer() {
        miniPlayerView?.removeFromSuperview()
        miniPlayerView = nil
        miniPlayerBottomConstraint = nil
        stopObservingPlayer()
    }
    
    // MARK: - Player Observation
    
    private func startObservingPlayer() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserver = PlayerCenter.shared.player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] _ in
            self?.updateMiniPlayerUI()
        }
        
        // Observe playback end
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMiniPlayerUI),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }
    
    private func stopObservingPlayer() {
        if let observer = timeObserver {
            PlayerCenter.shared.player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func updateMiniPlayerUI() {
        let player = PlayerCenter.shared.player
        guard let currentItem = player.currentItem else { return }
        
        let currentTime = player.currentTime().seconds
        let duration = currentItem.duration.seconds
        let progress = duration > 0 ? Float(currentTime / duration) : 0
        let isPlaying = player.timeControlStatus == .playing
        
        // Get title from Now Playing info
        let title = MPNowPlayingInfoCenter.default()
            .nowPlayingInfo?[MPMediaItemPropertyTitle] as? String ?? "Unknown"
        
        miniPlayerView?.updateUI(
            title: title,
            isPlaying: isPlaying,
            progress: progress
        )
    }
    
    // MARK: - Actions
    
    private func expandToFullPlayer() {
        guard let tabBarController = UIApplication.shared.rootTabBarController else {
            print("❌ Tab bar controller not found")
            return
        }
        
        let playerVC = MediaPlayerViewController()
        playerVC.downloadsResults = downloadsResults
        
        // Attach to current playing URL
        if let url = PlayerCenter.shared.currentURL {
            playerVC.startAt(url: url)
        }
        
        playerVC.modalPresentationStyle = .overFullScreen
        playerVC.modalTransitionStyle = .coverVertical
        
        tabBarController.present(playerVC, animated: true)
    }
    
    private func togglePlayPause() {
        if PlayerCenter.shared.isPlaying() {
            PlayerCenter.shared.pause()
        } else {
            PlayerCenter.shared.player.play()
        }
        
        updateMiniPlayerUI()
    }
}
