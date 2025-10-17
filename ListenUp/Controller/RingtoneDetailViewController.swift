//
//  RingtoneDetailViewController.swift
//  ListenUp
//
//  Created by S M H  on 16/10/2025.
//

import UIKit
import AVFoundation

class RingtoneDetailViewController: UIViewController {
    
    private let ringtone: Ringtone
    private var player: AVPlayer?
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let thumbnailImageView = UIImageView()
    private let titleLabel = UILabel()
    private let categoryLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private let downloadButton = UIButton(type: .system)
    private let statsLabel = UILabel()
    
    init(ringtone: Ringtone) {
        self.ringtone = ringtone
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        title = ringtone.title
        
        setupUI()
        configureData()
    }
    
    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let buttonContainer = UIView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(downloadButton)
        buttonContainer.addSubview(playButton)
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create info rows
        let durationRow = createInfoRow(icon: "clock.fill", title: "Duration", value: ringtone.durationFormatted ?? "N/A")
        let sizeRow = createInfoRow(icon: "doc.fill", title: "Size", value: ringtone.fileSizeFormatted ?? "N/A")
        let downloadRow = createInfoRow(icon: "arrow.down.circle.fill", title: "Downloads", value: "\(ringtone.downloadCount)")
        let playRow = createInfoRow(icon: "play.circle.fill", title: "Plays", value: "\(ringtone.playCount)")
        
        // Add all subviews
        [thumbnailImageView, titleLabel, categoryLabel, durationRow, sizeRow, downloadRow, playRow, buttonContainer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        // Setup constraints
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Thumbnail
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            thumbnailImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 200),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 200),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Category
            categoryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            categoryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            categoryLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            // Info Rows (Vertical Stack)
            durationRow.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 30),
            durationRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            durationRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            durationRow.heightAnchor.constraint(equalToConstant: 44),
            
            sizeRow.topAnchor.constraint(equalTo: durationRow.bottomAnchor, constant: 12),
            sizeRow.leadingAnchor.constraint(equalTo: durationRow.leadingAnchor),
            sizeRow.trailingAnchor.constraint(equalTo: durationRow.trailingAnchor),
            sizeRow.heightAnchor.constraint(equalToConstant: 44),
            
            downloadRow.topAnchor.constraint(equalTo: sizeRow.bottomAnchor, constant: 12),
            downloadRow.leadingAnchor.constraint(equalTo: durationRow.leadingAnchor),
            downloadRow.trailingAnchor.constraint(equalTo: durationRow.trailingAnchor),
            downloadRow.heightAnchor.constraint(equalToConstant: 44),
            
            playRow.topAnchor.constraint(equalTo: downloadRow.bottomAnchor, constant: 12),
            playRow.leadingAnchor.constraint(equalTo: durationRow.leadingAnchor),
            playRow.trailingAnchor.constraint(equalTo: durationRow.trailingAnchor),
            playRow.heightAnchor.constraint(equalToConstant: 44),
            
            buttonContainer.topAnchor.constraint(equalTo: playRow.bottomAnchor, constant: 30),
            buttonContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            buttonContainer.heightAnchor.constraint(equalToConstant: 50),
            buttonContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30),
            
            // Download Button (Left)
            downloadButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            downloadButton.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            downloadButton.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor),
            downloadButton.widthAnchor.constraint(equalToConstant: 140),
            
            // Play Button (Right)
            playButton.leadingAnchor.constraint(equalTo: downloadButton.trailingAnchor, constant: 12),
            playButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            playButton.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            playButton.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 140),
        ])
        
        // Style elements
        thumbnailImageView.layer.cornerRadius = 16
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.contentMode = .scaleAspectFit
        thumbnailImageView.backgroundColor = .systemGray5
        
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        
        categoryLabel.font = .systemFont(ofSize: 16)
        categoryLabel.textColor = .secondaryLabel
        categoryLabel.textAlignment = .center
        
        // Play Button (Red accent)
        playButton.setTitle("Play", for: .normal)
        playButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        playButton.backgroundColor = .systemRed
        playButton.setTitleColor(.white, for: .normal)
        playButton.layer.cornerRadius = 12
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        
        // Download Button (Neutral gray)
        downloadButton.setTitle("Download", for: .normal)
        downloadButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        downloadButton.backgroundColor = .systemGray3
        downloadButton.setTitleColor(.white, for: .normal)
        downloadButton.layer.cornerRadius = 12
        downloadButton.addTarget(self, action: #selector(downloadTapped), for: .touchUpInside)
        
    }
    
    private func configureData() {
        titleLabel.text = ringtone.title
        categoryLabel.text = ringtone.category?.name ?? "Unknown Category"
        
        statsLabel.text = """
                Duration: \(ringtone.durationFormatted ?? "N/A")
                Size: \(ringtone.fileSizeFormatted ?? "N/A")
                Downloads: \(ringtone.downloadCount)
                Plays: \(ringtone.playCount)
                """
        
        // Load thumbnail
        if let thumbnailUrl = ringtone.thumbnailUrl, let url = URL(string: thumbnailUrl) {
            // Use SDWebImage or URLSession to load image
            loadImage(from: url)
        } else {
            thumbnailImageView.image = UIImage(systemName: "music.note")
        }
    }
    
    private func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.thumbnailImageView.image = image
            }
        }.resume()
    }
    
    // Helper function to create info rows
    private func createInfoRow(icon: String, title: String, value: String) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .systemGray6
        containerView.layer.cornerRadius = 10
        
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: icon)
        iconImageView.tintColor = .systemGray
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 16, weight: .regular)
        valueLabel.textColor = .secondaryLabel
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            valueLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
        ])
        
        return containerView
    }
    
    @objc private func playTapped() {
//        guard let url = URL(string: ringtone.fileUrl!) else { return }
        guard let url = URL(string: "http://192.168.10.65:8000/storage/ringtones/1dee5636-7a81-4148-816b-655bf8199fa2.mp3") else { return }
        
        Task {
            try? await APIService.shared.trackPlay(ringtoneId: ringtone.id)
        }
        
        if player == nil {
            player = AVPlayer(url: url)
            player?.play()
            playButton.setTitle("⏸ Pause", for: .normal)
        } else {
            if player?.timeControlStatus == .playing {
                player?.pause()
                playButton.setTitle("▶️ Play", for: .normal)
            } else {
                player?.play()
                playButton.setTitle("⏸ Pause", for: .normal)
            }
        }
    }
    
    @objc private func downloadTapped() {
        // Show loading
        downloadButton.isEnabled = false
        downloadButton.setTitle("Downloading...", for: .normal)
        
        Task {
            do {
                // Track download
                try await APIService.shared.trackDownload(ringtoneId: ringtone.id)
                
                // Download file
//                guard let url = URL(string: ringtone.fileUrl!) else { return }
                guard let url = URL(string: "http://192.168.10.65:8000/storage/ringtones/1dee5636-7a81-4148-816b-655bf8199fa2.mp3") else { return }
                let (localURL, _) = try await URLSession.shared.download(from: url)
                
                // Save to Documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsPath.appendingPathComponent(ringtone.fileName ?? "Unknown")
                
                // Remove existing file if any
                try? FileManager.default.removeItem(at: destinationURL)
                
                // Move downloaded file
                try FileManager.default.moveItem(at: localURL, to: destinationURL)
                
                await MainActor.run {
                    downloadButton.setTitle("✅ Downloaded", for: .normal)
                    downloadButton.isEnabled = true
                    
                    // Show success alert
                    let alert = UIAlertController(
                        title: "Success",
                        message: "Ringtone downloaded successfully!",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                    
                    // Reset button after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.downloadButton.setTitle("⬇️ Download", for: .normal)
                    }
                }
                
            } catch {
                await MainActor.run {
                    downloadButton.setTitle("⬇️ Download", for: .normal)
                    downloadButton.isEnabled = true
                    
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to download ringtone: \(error.localizedDescription)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }
    
    deinit {
        player?.pause()
        player = nil
    }
}
