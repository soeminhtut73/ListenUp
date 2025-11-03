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

final class MiniPlayerContainerViewController: UIViewController {
    
    // MARK: - Singleton
    static let shared = MiniPlayerContainerViewController()
    
    // MARK: - UI
    private var miniPlayerView: MiniPlayerView?
    private var miniPlayerBottomConstraint: NSLayoutConstraint?
    private let miniPlayerHeight: CGFloat = 65
    
    // MARK: - Player observation
    private var timeObserver: Any?
    private var notiTokens: [NSObjectProtocol] = []
    
    // MARK: - State
    private var isShowing = false
    
    // MARK: - Realm Access
    private var downloadsResults: Results<DownloadItem>? {
        RealmService.shared.fetchAllMedia()
            .sorted(byKeyPath: "createdAt", ascending: false)
    }
    
    // MARK: - Init
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stopObservingPlayer()
    }
    
    // MARK: - Public show / hide
    
    func show(in tabBarController: UITabBarController, animated: Bool = true) {
        guard !isShowing else { return }
        isShowing = true
        
        // Make sure remote commands are centralized
        PlayerCenter.shared.setupRemoteCommands()
        
        let miniPlayer = createMiniPlayer()
        miniPlayer.alpha = animated ? 0 : 1
        tabBarController.view.addSubview(miniPlayer)
        
        let bottomConstraint = setupConstraints(
            for: miniPlayer,
            in: tabBarController,
            initialOffset: animated ? miniPlayerHeight : 0
        )
        
        self.miniPlayerView = miniPlayer
        self.miniPlayerBottomConstraint = bottomConstraint
        
        configureMiniPlayerActions()
        startObservingPlayer()
        
        tabBarController.adjustForMiniPlayer(height: miniPlayerHeight, animated: animated)
        
        if animated {
            animateShow(in: tabBarController, bottomConstraint: bottomConstraint, miniPlayer: miniPlayer)
        } else {
            bottomConstraint.constant = 0
        }
    }
    
    func hide(animated: Bool = true) {
        guard isShowing, let miniPlayerView = miniPlayerView else { return }
        isShowing = false
        
        // Adjust tab bar if possible
        if let tabBarController = miniPlayerView.window?.rootViewController as? UITabBarController {
            tabBarController.adjustForMiniPlayer(height: 0, animated: animated)
        }
        
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
        // 1) periodic progress (you already had this)
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = PlayerCenter.shared.player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] _ in
            self?.updateMiniPlayerUI()
        }
        
        // 2) central “next/prev requested” from PlayerCenter
        let nc = NotificationCenter.default
        
        let nextTok = nc.addObserver(
            forName: .playerCenterNextRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.playRelative(offset: 1)
        }
        
        let prevTok = nc.addObserver(
            forName: .playerCenterPrevRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.playRelative(offset: -1)
        }
        
        notiTokens = [nextTok, prevTok]
        
        // 3) still listen to end → just to refresh
        nc.addObserver(
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
        
        for tok in notiTokens {
            NotificationCenter.default.removeObserver(tok)
        }
        notiTokens.removeAll()
        
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
    
    // MARK: - Playlist navigation (for next/prev when full player is gone)
    
    /// Plays the item relative to current playing URL inside downloadsResults
    private func playRelative(offset: Int) {
        guard
            let results = downloadsResults,
            let currentURL = PlayerCenter.shared.currentURL
        else { return }
        
        // find current index in Realm list
        let currentIndex = results.firstIndex { item in
            guard let rel = item.localPath,
                  let url = FileHelper.fileURL(for: rel)
            else { return false }
            return url == currentURL
        }
        
        guard let idx = currentIndex else { return }
        
        let targetIndex = idx + offset
        
        // wrap for "all" style behaviour
        let finalIndex: Int
        if targetIndex < 0 {
            finalIndex = results.count - 1
        } else if targetIndex >= results.count {
            finalIndex = 0
        } else {
            finalIndex = targetIndex
        }
        
        let targetItem = results[finalIndex]
        guard let rel = targetItem.localPath,
              let url = FileHelper.fileURL(for: rel)
        else { return }
        
        PlayerCenter.shared.play(url: url)
        updateMiniPlayerUI()
    }
    
    // MARK: - Actions
    
    private func expandToFullPlayer() {
        guard let tabBarController = UIApplication.shared.rootTabBarController else {
            print("❌ Tab bar controller not found")
            return
        }
        
        let playerVC = MediaPlayerViewController()
        playerVC.downloadsResults = downloadsResults
        
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
