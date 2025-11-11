//
//  RingtoneTrimWithStripViewController.swift
//  ListenUp
//
//  Created by S M H  on 21/10/2025.
//

import UIKit
import AVFoundation
import AVKit

public final class RingtoneTrimWithStripViewController: UIViewController, ThumbnailStripViewDelegate {

    // Inputs
    private let item: DownloadItem
    private let videoURL: URL
    private let clipLength: TimeInterval = 30

    // AV
    private var asset: AVURLAsset!
    private var player: AVPlayer!
    private var playerLayer: AVPlayerLayer!
    private var timeObserver: Any?
    private var endObserver: Any?
    private var assetDuration: TimeInterval = 0

    // UI
    private let videoContainer = UIView()
    private let titleLabel = UILabel()
    private let strip = ThumbnailStripView()
    private let exportButton = UIButton(type: .system)
    private let timesLabel = UILabel()

    // State
    private var startTime: TimeInterval = 0 {
        didSet {
            updateTimesLabel()
            updateLoopBoundary()
            seekToStart(play: true)
        }
    }
    private var endTime: TimeInterval { min(assetDuration, startTime + clipLength) }

    // Init
    init(videoURL: URL, item: DownloadItem) {
        self.item = item
        self.videoURL = videoURL
        self.titleLabel.text = item.title
        
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder: NSCoder) { fatalError() }

    // Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Trim"

        setupAV()
        setupUI()
        layoutUI()
        configureObservers()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer.frame = videoContainer.bounds
    }

    deinit { cleanupObservers() }

    // Setup
    private func setupAV() {
        let duration = CMTime(seconds: item.duration, preferredTimescale: 600)
        
        asset = AVURLAsset(url: videoURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        assetDuration = max(0, CMTimeGetSeconds(duration))

        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        videoContainer.layer.addSublayer(playerLayer)
    }

    private func setupUI() {
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)
        
        videoContainer.backgroundColor = .black
//        videoContainer.layer.cornerRadius = 20
        view.addSubview(videoContainer)

        strip.delegate = self
        strip.layer.cornerRadius = 8
        strip.clipsToBounds = true
        view.addSubview(strip)
        strip.setAsset(asset, clipLength: clipLength)

        timesLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        timesLabel.textColor = .secondaryLabel
        timesLabel.textAlignment = .center
        view.addSubview(timesLabel)

        exportButton.setTitle("Export as Ringtone (.m4r)", for: .normal)
        exportButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        exportButton.backgroundColor = .systemBlue
        exportButton.tintColor = .white
        exportButton.layer.cornerRadius = 10
        exportButton.addTarget(self, action: #selector(tapExport), for: .touchUpInside)
        view.addSubview(exportButton)

        updateTimesLabel()
    }

    private func layoutUI() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        videoContainer.translatesAutoresizingMaskIntoConstraints = false
        strip.translatesAutoresizingMaskIntoConstraints = false
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        timesLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            videoContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 32),
            videoContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            videoContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            videoContainer.heightAnchor.constraint(equalTo: videoContainer.widthAnchor, multiplier: 9.0/16.0),

            strip.topAnchor.constraint(equalTo: videoContainer.bottomAnchor, constant: 20),
            strip.leadingAnchor.constraint(equalTo: videoContainer.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: videoContainer.trailingAnchor),
            strip.heightAnchor.constraint(equalToConstant: 72),

            timesLabel.topAnchor.constraint(equalTo: strip.bottomAnchor, constant: 8),
            timesLabel.leadingAnchor.constraint(equalTo: strip.leadingAnchor),
            timesLabel.trailingAnchor.constraint(equalTo: strip.trailingAnchor),

            exportButton.topAnchor.constraint(equalTo: timesLabel.bottomAnchor, constant: 16),
            exportButton.leadingAnchor.constraint(equalTo: strip.leadingAnchor),
            exportButton.trailingAnchor.constraint(equalTo: strip.trailingAnchor),
            exportButton.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    // Observers / Looping
    private func configureObservers() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
                                                      queue: .main) { [weak self] t in
            guard let self = self else { return }
            if CMTimeGetSeconds(t) >= self.endTime {
                self.seekToStart(play: true)
            }
        }
        updateLoopBoundary()
        seekToStart(play: true)
    }

    private func cleanupObservers() {
        if let endObserver { player.removeTimeObserver(endObserver) }
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        endObserver = nil
        timeObserver = nil
    }

    private func updateLoopBoundary() {
        if let endObserver { player.removeTimeObserver(endObserver) }
        let endCM = CMTime(seconds: endTime, preferredTimescale: 600)
        endObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: endCM)], queue: .main) { [weak self] in
            self?.seekToStart(play: true)
        }
    }

    private func seekToStart(play: Bool) {
        let startCM = CMTime(seconds: startTime, preferredTimescale: 600)
        player.seek(to: startCM, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            if play { self?.player.play() }
        }
    }

    private func updateTimesLabel() {
        timesLabel.text = "Start At: \(format(startTime))     |     End At: \(format(endTime))"
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.down))
        return String(format: "%02d:%02d", s/60, s%60)
    }

    // Delegate
    public func strip(_ strip: ThumbnailStripView, didChangeStartTime start: TimeInterval) {
        startTime = start
    }

    // Export
    @objc private func tapExport() {
        exportButton.isEnabled = false
        exportButton.alpha = 0.6
        
        AudioConverter.shared.convertToAudio(with: item.title, from: videoURL, startTime: startTime) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.exportButton.isHidden = true
                self.exportButton.alpha = 1.0
                
                switch result {
                case .success(let outputURL):
                    let av = UIActivityViewController(activityItems: [outputURL], applicationActivities: nil)
                    self.present(av, animated: true)
                    
                case .failure(let err):
                    let alert = UIAlertController(title: "Export Failed", message: err.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}
