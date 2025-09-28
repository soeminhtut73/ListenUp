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

class MiniPlayerContainerViewController: UIViewController {
    
    static let shared = MiniPlayerContainerViewController()
    
    private var miniPlayerView: MiniPlayerView?
    private var miniPlayerBottomConstraint: NSLayoutConstraint?
    private var timeObserver: Any?
    
    private let miniPlayerHeight: CGFloat = 65
    private var isShowing = false
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var realm: Realm? {
        return try? Realm()
    }
    
    private var downloadsResults: Results<DownloadItem>? {
        // This query is lazy - Realm doesn't load all items into memory
        return RealmService.shared.fetchAllMedia().sorted(byKeyPath: "createdAt", ascending: false)
    }
    
    func show(in tabBarController: UITabBarController) {
        guard !isShowing else { return }
        isShowing = true

        // Create mini player
        let miniPlayer = MiniPlayerView()
        miniPlayer.translatesAutoresizingMaskIntoConstraints = false
        tabBarController.view.addSubview(miniPlayer)
        
        // Position above tab bar
        let bottomConstraint = miniPlayer.bottomAnchor.constraint(
            equalTo: tabBarController.tabBar.topAnchor,
            constant: miniPlayerHeight // Initially hidden
        )
        
        NSLayoutConstraint.activate([
            miniPlayer.leadingAnchor.constraint(equalTo: tabBarController.view.leadingAnchor),
            miniPlayer.trailingAnchor.constraint(equalTo: tabBarController.view.trailingAnchor),
            miniPlayer.heightAnchor.constraint(equalToConstant: miniPlayerHeight),
            bottomConstraint
        ])
        
        self.miniPlayerView = miniPlayer
        self.miniPlayerBottomConstraint = bottomConstraint
        
        // Configure actions
        miniPlayer.onTap = { [weak self] in
            self?.expandToFullPlayer()
        }
        
        miniPlayer.onPlayPause = { [weak self] in
            self?.togglePlayPause()
        }
        
        // Start observing player
        startObservingPlayer()
        
        // Animate in
        tabBarController.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            bottomConstraint.constant = 0
            tabBarController.view.layoutIfNeeded()
        }
    }
    
    func hide() {
        guard isShowing, let miniPlayerView = miniPlayerView else { return }
        isShowing = false
        
        UIView.animate(withDuration: 0.3, animations: {
            self.miniPlayerBottomConstraint?.constant = self.miniPlayerHeight
            miniPlayerView.superview?.layoutIfNeeded()
        }) { _ in
            miniPlayerView.removeFromSuperview()
            self.miniPlayerView = nil
            self.miniPlayerBottomConstraint = nil
            self.stopObservingPlayer()
        }
    }
    
    private func startObservingPlayer() {
        let player = PlayerCenter.shared.player
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateMiniPlayerUI()
        }
        
        // Observe player item changes
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
        
        // Get title from Now Playing info if available
        let title = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String ?? "Unknown"
        
        miniPlayerView?.updateUI(
            title: title,
            isPlaying: isPlaying,
            progress: progress
        )
    }
    
    private func expandToFullPlayer() {
        // Present the full player
        guard let tabBarController = UIApplication.shared.rootTabBarController else { return }
        
        // FIXME: - To update download result
        let playerVC = MediaPlayerViewController()
        playerVC.downloadsResults = downloadsResults
        
        if let url = (PlayerCenter.shared.player.currentItem?.asset as? AVURLAsset)?.url {
            playerVC.startAt(url: url)   // tells the full VC: “attach to this one”
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

extension MiniPlayerContainerViewController {
    
    func show(in tabBarController: UITabBarController, animated: Bool = true) {
        guard !isShowing else { return }
        isShowing = true
        
        // Create mini player
        let miniPlayer = MiniPlayerView()
        miniPlayer.translatesAutoresizingMaskIntoConstraints = false
        miniPlayer.alpha = 0
        tabBarController.view.addSubview(miniPlayer)
        
        // Position above tab bar
        let bottomConstraint = miniPlayer.bottomAnchor.constraint(
            equalTo: tabBarController.tabBar.topAnchor,
            constant: animated ? miniPlayerHeight : 0
        )
        
        NSLayoutConstraint.activate([
            miniPlayer.leadingAnchor.constraint(equalTo: tabBarController.view.leadingAnchor),
            miniPlayer.trailingAnchor.constraint(equalTo: tabBarController.view.trailingAnchor),
            miniPlayer.heightAnchor.constraint(equalToConstant: miniPlayerHeight),
            bottomConstraint
        ])
        
        self.miniPlayerView = miniPlayer
        self.miniPlayerBottomConstraint = bottomConstraint
        
        // Configure actions
        miniPlayer.onTap = { [weak self] in
            self?.expandToFullPlayer()
        }
        
        miniPlayer.onPlayPause = { [weak self] in
            self?.togglePlayPause()
        }
        
        // Start observing player
        startObservingPlayer()
        
        // Adjust tab bar content
        tabBarController.adjustForMiniPlayer(height: miniPlayerHeight, animated: animated)
        
        // Animate in
        if animated {
            tabBarController.view.layoutIfNeeded()
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                bottomConstraint.constant = 0
                miniPlayer.alpha = 1
                tabBarController.view.layoutIfNeeded()
            }
        } else {
            bottomConstraint.constant = 0
            miniPlayer.alpha = 1
        }
    }
    
    func hide(animated: Bool = true) {
        guard isShowing, let miniPlayerView = miniPlayerView else { return }
        isShowing = false
        
        // Find tab bar controller
        if let tabBarController = miniPlayerView.window?.rootViewController as? UITabBarController {
            tabBarController.adjustForMiniPlayer(height: 0, animated: animated)
        }
        
        let completion = {
            miniPlayerView.removeFromSuperview()
            self.miniPlayerView = nil
            self.miniPlayerBottomConstraint = nil
            self.stopObservingPlayer()
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                self.miniPlayerBottomConstraint?.constant = self.miniPlayerHeight
                miniPlayerView.alpha = 0
                miniPlayerView.superview?.layoutIfNeeded()
            }) { _ in
                completion()
            }
        } else {
            completion()
        }
    }
}
