//
//  MiniPlayerController.swift
//  ListenUp
//
//  Created by S M H  on 06/11/2025.
//

import UIKit
import AVFoundation
import MediaPlayer
import RealmSwift

protocol MiniPlayerAdjustable: AnyObject {
    func setMiniPlayerVisible(_ visible: Bool, height: CGFloat)
}

final class MiniPlayerController: UIViewController {
    
    // MARK: - Singleton
    static let shared = MiniPlayerController()
    
    // MARK: - UI
    private var miniPlayerView: MiniPlayerView!
    private var miniPlayerBottomConstraint: NSLayoutConstraint?
    private let miniPlayerHeight: CGFloat = 65
    
    // MARK: - Player observation
    private var timeObserver: Any?
    private var notiTokens: [NSObjectProtocol] = []
    
    // MARK: - Realm Access
    private var downloadsResults: Results<DownloadItem>!
    
    private var isVisible: Bool = false
    
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
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false   // container itself doesn’t need touches
    }
    
    func setPlaylist(with playlists: Results<DownloadItem>) {
        downloadsResults = playlists
    }
    
    // call this once after tab bar is ready (e.g. from SceneDelegate/app entry)
    func attach(to tabBarController: UITabBarController) {
        if miniPlayerView != nil { return }
        
        PlayerCenter.shared.setupRemoteCommands()
        
        let mini = createMiniPlayer()
        tabBarController.view.addSubview(mini)
        let bottomConstraint = setupConstraints(
            for: mini,
            in: tabBarController
        )
        
        self.miniPlayerView = mini
        self.miniPlayerBottomConstraint = bottomConstraint
        
        configureMiniPlayerActions()
        startObservingPlayer()
        
        // optionally tell current screen to leave room for it
        if let top = (tabBarController.selectedViewController as? UINavigationController)?.topViewController as? MiniPlayerAdjustable {
            top.setMiniPlayerVisible(true, height: miniPlayerHeight)
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
        in tabBarController: UITabBarController
    ) -> NSLayoutConstraint {
        let bottomConstraint = miniPlayer.bottomAnchor.constraint(
            equalTo: tabBarController.tabBar.topAnchor,
            constant: 0
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
        miniPlayerView.onTap = { [weak self] in
            self?.expandToFullPlayer()
        }
        
        miniPlayerView.onPlayPause = { [weak self] in
            self?.togglePlayPause()
        }
    }
    
    // MARK: - Player Observation
    
    private func startObservingPlayer() {
        // periodic progress
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = PlayerCenter.shared.player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] _ in
            self?.updateMiniPlayerUI()
        }
        
        // listen to PlayerCenter “next/prev” so we can advance even when full player is gone
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
        
        // refresh on end
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
        guard let currentItem = player.currentItem else {
            miniPlayerView.updateUI(title: "Not playing", isPlaying: false, progress: 0)
            return
        }
        
        let currentTime = player.currentTime().seconds
        let duration = currentItem.duration.seconds
        let progress = duration > 0 ? Float(currentTime / duration) : 0
        let isPlaying = player.timeControlStatus == .playing
        
        let title = MPNowPlayingInfoCenter.default()
            .nowPlayingInfo?[MPMediaItemPropertyTitle] as? String ?? "Unknown"
        
        miniPlayerView.updateUI(
            title: title,
            isPlaying: isPlaying,
            progress: progress
        )
    }
    
    // MARK: - Playlist navigation
    
    private func playRelative(offset: Int) {
        guard
            let results = downloadsResults,
            let currentURL = PlayerCenter.shared.currentURL
        else { return }
        
        
        let currentIndex = results.firstIndex { item in
            guard let rel = item.localPath,
                  let url = FileHelper.fileURL(for: rel)
            else { return false }
            return url == currentURL
        }
        
        guard let idx = currentIndex else { return }
        
        let targetIndex = idx + offset
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
        
        // pass id if you added that to PlayerCenter
        PlayerCenter.shared.play(url: url, itemID: targetItem.id)
        updateMiniPlayerUI()
    }
    
    // MARK: - Actions
    
    private func expandToFullPlayer() {
        guard let tabBarController = UIApplication.shared.rootTabBarController else {
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
    
    func hide(animated: Bool = true) {
        guard isVisible else { return }
        isVisible = false
        UIView.animate(withDuration: animated ? 0.25 : 0) {
            self.miniPlayerView?.alpha = 0
            self.miniPlayerView?.isUserInteractionEnabled = false
        }
    }
    
    func show(animated: Bool = true) {
        guard !isVisible else { return }
        isVisible = true
        UIView.animate(withDuration: animated ? 0.25 : 0) {
            self.miniPlayerView?.alpha = 1
            self.miniPlayerView?.isUserInteractionEnabled = true
        }
    }
    
}
