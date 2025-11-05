//
//  DownloadTableViewCell.swift
//  ListenUp
//
//  Created by S M H  on 24/10/2025.
//

import Foundation
import UIKit
import Combine
import AVFoundation
import SDWebImage

// MARK: - Display Mode
enum DownloadCellDisplayMode {
    case video
    case audio
}

// MARK: - Delegate Protocol
protocol DownloadTableViewCellDelegate: AnyObject {
    func cell(_ cell: DownloadTableViewCell, didTapOptionFor item: DownloadItem)
}

// MARK: - Cell
class DownloadTableViewCell: UITableViewCell {
    static let identifier = "DownloadTableViewCell"
    
    private var currentItemId: String?
    private var currentItem: DownloadItem?
    private var displayMode: DownloadCellDisplayMode = .video
    
    //MARK: - UIComponent
    
    private let playingIndicator = PlayingIndicatorView()
    
    private let albumImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .systemGray5
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        imageView.isHidden = true
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.numberOfLines = 1
        label.textColor = .label
        return label
    }()
    
    lazy var optionButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: "ellipsis.circle", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.addTarget(self, action: #selector(handleOptionButtonTapped), for: .touchUpInside)
        button.isUserInteractionEnabled = true
        return button
    }()
    
    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let circularProgressView: CircularProgressView = {
        let view = CircularProgressView.appStoreStyle(size: 40)
        view.isHidden = true
        return view
    }()
    
    weak var delegate: DownloadTableViewCellDelegate?
    
    //MARK: - Lifecycle
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        
        preservesSuperviewLayoutMargins = false
        contentView.preservesSuperviewLayoutMargins = false
        shouldIndentWhileEditing = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        currentItemId = nil
        currentItem = nil
        albumImageView.image = nil
        circularProgressView.reset(animated: false)
        detailLabel.text = nil
        titleLabel.textColor = .label
        playingIndicator.stop()
        setPlaying(false)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        optionButton.isHidden = editing

        if animated {
            UIView.animate(withDuration: 0.25) { self.layoutIfNeeded() }
        } else {
            setNeedsLayout()
        }
    }
    
    private func setupUI() {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        stackView.axis = .vertical
        stackView.spacing = 6
        stackView.distribution = .fillProportionally
        
        playingIndicator.barColor = .label
        playingIndicator.barCount = 4
        playingIndicator.backgroundColor = .clear
        
        [albumImageView, stackView, optionButton, circularProgressView, playingIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        contentView.isUserInteractionEnabled = true
        
        NSLayoutConstraint.activate([
            // Album image
            albumImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            albumImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            albumImageView.widthAnchor.constraint(equalToConstant: 46),
            albumImageView.heightAnchor.constraint(equalToConstant: 46),
            
            // Playing indicator (over album)
            playingIndicator.centerXAnchor.constraint(equalTo: albumImageView.centerXAnchor),
            playingIndicator.centerYAnchor.constraint(equalTo: albumImageView.centerYAnchor),
            playingIndicator.widthAnchor.constraint(equalToConstant: 24),
            playingIndicator.heightAnchor.constraint(equalToConstant: 24),
            
            // Circular progress (over album)
            circularProgressView.centerXAnchor.constraint(equalTo: albumImageView.centerXAnchor),
            circularProgressView.centerYAnchor.constraint(equalTo: albumImageView.centerYAnchor),
            circularProgressView.widthAnchor.constraint(equalToConstant: 40),
            circularProgressView.heightAnchor.constraint(equalToConstant: 40),
            
            // Option button
            optionButton.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            optionButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            optionButton.widthAnchor.constraint(equalToConstant: 30),
            optionButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Stack view
            stackView.leadingAnchor.constraint(equalTo: albumImageView.trailingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: optionButton.leadingAnchor, constant: -12),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        playingIndicator.isHidden = true
    }
    
    // MARK: - Public Configuration Method
    /// Main entry point to configure the cell
    func configure(with item: DownloadItem, mode: DownloadCellDisplayMode) {
        self.currentItem = item
        self.displayMode = mode
        
        titleLabel.text = item.title
        albumImageView.isHidden = true
        
        let isDifferentItem = currentItemId != item.id
        currentItemId = item.id
        
        // Configure based on status
        configureForStatus(item: item, isDifferentItem: isDifferentItem)
        
        // Configure details based on mode
        configureDetailLabel(for: item, mode: mode)
        
        // Configure thumbnail based on media type
        if item.status == .completed {
            configureThumbnail(for: item, mode: mode)
        }
    }
    
    // MARK: - Status Configuration
    private func configureForStatus(item: DownloadItem, isDifferentItem: Bool) {
        switch item.status {
        case .running:
            circularProgressView.isHidden = false
//            albumImageView.isHidden = true
            circularProgressView.setProgress(item.progress, for: item.id, animated: !isDifferentItem)
//            circularProgressView.setProgress(item.progress, for: item.id)
            
        case .completed:
            albumImageView.isHidden = false
            circularProgressView.setCompleted(for: item.id)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self, self.currentItemId == item.id else { return }
                self.circularProgressView.isHidden = true
            }
            
        case .failed:
            circularProgressView.isHidden = true
            albumImageView.isHidden = false
            titleLabel.text = "Failed to download!"
            titleLabel.textColor = .systemRed
            
        case .queued:
            circularProgressView.isHidden = false
            albumImageView.isHidden = true
            
        case .canceled:
            circularProgressView.isHidden = true
            albumImageView.isHidden = false
            titleLabel.text = "Canceled!"
            titleLabel.textColor = .secondaryLabel
        }
    }
    
    // MARK: - Detail Label Configuration
    private func configureDetailLabel(for item: DownloadItem, mode: DownloadCellDisplayMode) {
        var detailComponents: [String] = []
        
        // Add file size if available
        if item.fileSize > 0 {
            detailComponents.append(item.fileSize.fileSizeString)
        }
        
        // Add duration if available
        if item.duration > 0 {
            detailComponents.append(item.duration.timeFormattedString)
        }
        
        // Add format if available
        if !item.format.isEmpty {
            detailComponents.append(item.format.uppercased())
        }

        detailLabel.text = detailComponents.isEmpty ? "Unknown size" : detailComponents.joined(separator: " | ")
    }
    
    // MARK: - Thumbnail Configuration
    private func configureThumbnail(for item: DownloadItem, mode: DownloadCellDisplayMode) {
        if let url = URL(string: item.thumbURL), !item.thumbURL.isEmpty, mode == .video {
            albumImageView.sd_setImage(
                with: url,
                placeholderImage: UIImage(systemName: "play.rectangle.fill"),
                options: [.retryFailed, .continueInBackground]
            )
        } else {
            albumImageView.image = UIImage(systemName: "music.note")
            albumImageView.contentMode = .center
        }
    }
    
    // MARK: - Actions
    @objc private func handleOptionButtonTapped() {
        guard let item = currentItem else { return }
        delegate?.cell(self, didTapOptionFor: item)
    }
    
    // MARK: - Playing State
    /// Call from controller to toggle animation on/off
    func setPlaying(_ isPlaying: Bool) {
        if isPlaying {
            playingIndicator.isHidden = false
            albumImageView.layer.opacity = 0.5
            playingIndicator.start()
        } else {
            playingIndicator.stop()
            albumImageView.layer.opacity = 1
            playingIndicator.isHidden = true
        }
    }
}
