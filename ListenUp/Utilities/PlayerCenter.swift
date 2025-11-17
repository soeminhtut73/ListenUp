//
//  PlayerCenter.swift
//  ListenUp
//
//  Created by S M H  on 15/09/2025.
//

import Foundation
import UIKit
import AVFoundation
import MediaPlayer

enum LoopMode { case off, one, all }

// MARK: - PlayerCenter
//@MainActor
final class PlayerCenter {
    
    // MARK: - Singleton
    
    static let shared = PlayerCenter()
    
    // MARK: - Properties
    
    let player = AVPlayer()
    
    private var remoteCommandsSetup = false
    
    var currentURL: URL? {
        (player.currentItem?.asset as? AVURLAsset)?.url
    }
    
    var isActuallyPlaying: Bool {
        player.rate > 0 && player.error == nil
    }
    
    private(set) var currentPlayingItemId: String?
    
    private(set) var loopMode: LoopMode = .all {
        didSet {
            NotificationCenter.default.post(name: .playerCenterLoopModeDidChange, object: self)
        }
    }
    
    private(set) var shuffleOn: Bool = false {
        didSet {
            NotificationCenter.default.post(name: .playerCenterShuffleDidChange, object: self)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        configureAudioSession()
        setupRemoteCommands()
        setupNotifications()
    }
    
    
    // MARK: - Setup
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    private func configureAudioSession() {
        let s = AVAudioSession.sharedInstance()
        do {
            try s.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetoothA2DP])
            try s.setActive(true)
        } catch { print("Audio session error:", error) }
    }
    
    func setupRemoteCommands() {
        guard !remoteCommandsSetup else { return }
        remoteCommandsSetup = true
        
        let cc = MPRemoteCommandCenter.shared()
        
        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.player.play()
            self.updateNowPlayingPlaybackRate(1.0)
            return .success
        }
        
        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.player.pause()
            self.updateNowPlayingPlaybackRate(0.0)
            return .success
        }
        
        cc.nextTrackCommand.isEnabled = true
        cc.nextTrackCommand.addTarget { [weak self] _ in
            guard self != nil else { return .commandFailed }
            NotificationCenter.default.post(name: .playerCenterNextRequested, object: nil)
            return .success
        }
        
        cc.previousTrackCommand.isEnabled = true
        cc.previousTrackCommand.addTarget { [weak self] _ in
            guard self != nil else { return .commandFailed }
            NotificationCenter.default.post(name: .playerCenterPrevRequested, object: nil)
            return .success
        }
        
        cc.changePlaybackPositionCommand.isEnabled = true
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let time = CMTime(seconds: e.positionTime, preferredTimescale: 600)
            self.player.seek(to: time)
            return .success
        }
        
        // End-of-item policy -> handled here
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self = self else { return }
            guard note.object as? AVPlayerItem === self.player.currentItem else { return }
            
            switch self.loopMode {
            case .one:
                self.player.seek(to: .zero)
                self.player.play()
            case .all:
                NotificationCenter.default.post(name: .playerCenterNextRequested, object: nil)
                NotificationCenter.default.post(name: .playerCenterItemChanged, object: nil)
            case .off:
                break
                
            }
        }
    }
    
    //MARK: - Configure loop/shuffle mode
    
    func toggleShuffle() {
        shuffleOn.toggle()
    }
    
    func setShuffle(_ on: Bool) {
        shuffleOn = on
    }
    
    func cycleLoopMode() {
        switch loopMode {
        case .off: loopMode = .one
        case .one: loopMode = .all
        case .all: loopMode = .off
        }
    }
    
    func setLoopMode(_ mode: LoopMode) {
        loopMode = mode
    }
    
    // MARK: - Playback Control
    
    func play(url: URL, itemID: String? = nil) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        player.play()
        currentPlayingItemId = itemID
        NotificationCenter.default.post(name: .playerCenterItemChanged, object: nil)
    }
    
    func pause() {
        player.pause()
    }
    
    func stop() {
        player.pause()
        currentPlayingItemId = nil
    }
    
    func setPlaying(_ playing: Bool) {
        if playing {
            player.play()
        } else {
            player.pause()
        }

        updatePlaybackRate(isPlaying: playing)
    }
    
    func isPlaying() -> Bool {
        return player.rate > 0.0
    }
    
    func setCurrentPlayingItem(id: String) {
        currentPlayingItemId = id
    }
    
    // MARK: - Seeking
    
    func seek(by delta: Double) {
        guard let item = player.currentItem else { return }
        
        let currentTime = player.currentTime().seconds
        let duration = item.duration.seconds
        var targetTime = currentTime + delta
        
        // Handle finite duration (VOD/local files)
        if duration.isFinite {
            targetTime = max(0, min(targetTime, max(0, duration - 0.01)))
        } else {
            // Handle live/indefinite streams
            targetTime = max(0, targetTime)
        }
        
        let wasPlaying = (player.timeControlStatus == .playing)
        let seekTime = CMTime(seconds: targetTime, preferredTimescale: 600)
        
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self = self, finished else { return }
            
            if wasPlaying {
                self.player.play()
            }
            
            self.updateElapsedTimeForNowPlaying()
        }
    }
    
    func skipForward15() {
        seek(by: 15)
    }
    
    func skipBackward15() {
        seek(by: -15)
    }
    
    // MARK: - Now Playing Info
    
    func updateNowPlaying(title: String, duration: Double, isPlaying: Bool) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func updateNowPlayingPlaybackRate(_ rate: Float) {
        if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            info[MPNowPlayingInfoPropertyPlaybackRate] = rate
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
    
    private func updateElapsedTimeForNowPlaying() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func updatePlaybackRate(isPlaying: Bool) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    }
    
    // MARK: - Interruption Handling
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch interruptionType {
        case .began:
            handleInterruptionBegan()
            
        case .ended:
            handleInterruptionEnded(userInfo: userInfo)
            
        @unknown default:
            break
        }
    }
    
    private func handleInterruptionBegan() {
        // Update Control Center - system may pause automatically
        updatePlaybackRate(isPlaying: false)
    }
    
    private func handleInterruptionEnded(userInfo: [AnyHashable: Any]) {
        // Check if we should resume playback
        let shouldResume = (userInfo[AVAudioSessionInterruptionOptionKey] as? UInt)
            .map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) } ?? false
        
        if shouldResume {
            setPlaying(true)
        }
    }
}
