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

final class PlayerCenter {
    static let shared = PlayerCenter()
    var player = AVPlayer()
    
    var currentURL: URL? {
        (player.currentItem?.asset as? AVURLAsset)?.url
    }
    
    private init() {
        player = AVPlayer()
        
        // Background audio
        configureAudioSession()
        
        // (Optional) Remote commands
        setupRemoteCommands()
        
        // Handle interruptions (phone calls, Siri, etc.)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil
        )
    }
    
    private func configureAudioSession() {
        let s = AVAudioSession.sharedInstance()
        do {
            try s.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetooth])
            try s.setActive(true)
        } catch { print("Audio session error:", error) }
    }
    
    private func setupRemoteCommands() {
        let cmd = MPRemoteCommandCenter.shared()
        cmd.playCommand.addTarget { [weak self] _ in self?.setPlaying(true);  return .success }
        cmd.pauseCommand.addTarget { [weak self] _ in self?.setPlaying(false); return .success }
        cmd.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let p = self?.player else { return .commandFailed }
            self?.setPlaying(p.timeControlStatus != .playing)
            return .success
        }
    }
    
    func play(url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        try? AVAudioSession.sharedInstance().setActive(true)
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
        // reflect in Control Center
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = playing ? 1.0 : 0.0
    }
    
    // Keep Control Center in sync
    func updateNowPlaying(title: String, duration: Double, isPlaying: Bool) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0   // 👈 important
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    func isPlaying() -> Bool {
        player.rate > 0.0
    }
    
    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeVal = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeVal) else { return }
        
        switch type {
        case .began:
            // Don’t force pause in Control Center; system may do it.
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        case .ended:
            // Resume if the system suggests
            let shouldResume = (info[AVAudioSessionInterruptionOptionKey] as? UInt).map {
                AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume)
            } ?? false
            if shouldResume { setPlaying(true) }
        @unknown default: break
        }
    }
}


