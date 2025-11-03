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

// MARK: - PlayerCenter

final class PlayerCenter {
    
    // MARK: - Singleton
    
    static let shared = PlayerCenter()
    
    // MARK: - Properties
    
    let player = AVPlayer()
    
    var currentURL: URL? {
        (player.currentItem?.asset as? AVURLAsset)?.url
    }
    
    var isActuallyPlaying: Bool {
        player.rate > 0 && player.error == nil
    }
    
    // MARK: - Initialization
    
    private init() {
        configureAudioSession()
        setupRemoteCommands()
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play Command
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.setPlaying(true)
            return .success
        }
        
        // Pause Command
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.setPlaying(false)
            return .success
        }
        
        // Toggle Play/Pause Command
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.setPlaying(self.player.timeControlStatus != .playing)
            return .success
        }
        
        // Skip Forward Command
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward15()
            return .success
        }
        
        // Skip Backward Command
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward15()
            return .success
        }
    }
    
    // MARK: - Playback Control
    
    func play(url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to activate audio session:", error)
        }
        
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func stop() {
        player.pause()
    }
    
    func setPlaying(_ playing: Bool) {
        if playing {
            player.play()
        } else {
            player.pause()
        }
        
        // Update Control Center
        updatePlaybackRate(isPlaying: playing)
    }
    
    func isPlaying() -> Bool {
        return player.rate > 0.0
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
