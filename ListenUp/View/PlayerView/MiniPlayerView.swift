//
//  MiniPlayerView.swift
//  ListenUp
//
//  Created by S M H  on 23/09/2025.
//

import UIKit
import AVFoundation

// MARK: - MiniPlayerView
final class MiniPlayerView: UIView {
    
    // UI Elements
    private let containerView = UIView()
    private let progressView = UIProgressView()
    private let thumbnailImageView = UIImageView()
    private let titleLabel = UILabel()
    private let playPauseButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    
    // Callbacks
    var onTap: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onNext: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        // Container with shadow
        containerView.backgroundColor = .systemBackground
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, height: -2)
        containerView.layer.shadowRadius = 4
        
        // Progress at top
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = .systemGray5
        
        // Thumbnail
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.tintColor = .secondaryLabel
        thumbnailImageView.layer.cornerRadius = 8
        thumbnailImageView.backgroundColor = .systemGray5
        
        // Title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .label
        
        // Buttons
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playPauseButton.tintColor = .label
        
        nextButton.setImage(UIImage(systemName: "forward.fill"), for: .normal)
        nextButton.tintColor = .label
        
        // Layout
        [containerView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        
        [progressView, thumbnailImageView, titleLabel, playPauseButton, nextButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            progressView.topAnchor.constraint(equalTo: containerView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            thumbnailImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            thumbnailImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 30),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 30),
            
            titleLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -12),
            
            playPauseButton.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor, constant: -16),
            playPauseButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 30),
            playPauseButton.heightAnchor.constraint(equalToConstant: 30),
            
            nextButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            nextButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 30),
            nextButton.heightAnchor.constraint(equalToConstant: 30),
        ])
        
        // Actions
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        containerView.addGestureRecognizer(tapGesture)
        
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
    }
    
    @objc private func handleTap() {
        onTap?()
    }
    
    @objc private func playPauseTapped() {
        onPlayPause?()
    }
    
    @objc private func nextTapped() {
        onNext?()
    }
    
    func updateUI(title: String, isPlaying: Bool, progress: Float, thumbnail: UIImage? = nil) {
        titleLabel.text = title
        playPauseButton.setImage(UIImage(systemName: isPlaying ? "pause.fill" : "play.fill"), for: .normal)
        progressView.progress = progress
        thumbnailImageView.image = UIImage(systemName: "music.quarternote.3")
    }
}
