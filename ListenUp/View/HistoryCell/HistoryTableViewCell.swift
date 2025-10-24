//
//  HistoryTableViewCell.swift
//  ListenUp
//
//  Created by S M H  on 21/07/2025.
//

import Foundation
import UIKit
import Combine
import AVFoundation
import SDWebImage

protocol HistoryTableViewCellDelegate: AnyObject {
    func didTapOptionButton(for cell: HistoryTableViewCell)
}


class HistoryTableViewCell: UITableViewCell {
    static let identifier = "HistoryTableViewCell"
    
    private var currentItemId: String?
    
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
    
    private let title: UILabel = {
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
    
    private var fileSizeLabel: UILabel = {
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
    
    weak var delegate: HistoryTableViewCellDelegate?
    
    
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
        albumImageView.image = nil
        circularProgressView.reset(animated: false)
        fileSizeLabel.text = nil
        setPlaying(false)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        if animated {
            UIView.animate(withDuration: 0.25) { self.layoutIfNeeded() }
        } else {
            setNeedsLayout()
        }
    }
    
    private func setupUI() {
        
        let stackView = UIStackView(arrangedSubviews: [title, fileSizeLabel])
        stackView.axis = .vertical
        stackView.spacing = 6
        stackView.distribution = .fillProportionally
        
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
            albumImageView.heightAnchor.constraint(equalToConstant: 46), // square
            
            // Playing indicator (over album)
            playingIndicator.centerXAnchor.constraint(equalTo: albumImageView.centerXAnchor),
            playingIndicator.centerYAnchor.constraint(equalTo: albumImageView.centerYAnchor),
            playingIndicator.widthAnchor.constraint(equalToConstant: 30),
            playingIndicator.heightAnchor.constraint(equalToConstant: 30),
            
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
            
            stackView.leadingAnchor.constraint(equalTo: albumImageView.trailingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: optionButton.leadingAnchor, constant: -12),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        playingIndicator.isHidden = true
    }
    
    // Bind download tasks, 
    func configure(with item: DownloadItem) {
        title.text = item.title
        albumImageView.isHidden = true
        
        let isDifferentItem = currentItemId != item.id
        currentItemId = item.id
        
        switch item.status {
        case.running:
            circularProgressView.isHidden = false
            
            circularProgressView.setProgress(item.progress, for: item.id, animated: !isDifferentItem)
            
        case.completed:
            albumImageView.isHidden = false
            circularProgressView.setCompleted(for: item.id)
            
            if item.fileSize > 0 {
                fileSizeLabel.text = formatFileSize(item.fileSize)
            } else if item.fileSize > 0 {
                fileSizeLabel.text = formatFileSize(item.fileSize)
            } else {
                fileSizeLabel.text = "Unknown size"
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.currentItemId == item.id {
                    self.circularProgressView.isHidden = true
                }
            }
            // to load thumbNail after complete
            configureThumbnail(for: item)
            
        case.failed:
            circularProgressView.isHidden = true
            albumImageView.isHidden = false
            title.text = "Failed to download!"
            title.textColor = .red
            
        case.queued:
            circularProgressView.isHidden = false
            albumImageView.isHidden = true
//            circularProgressView.progress = 0
            
        case.canceled:
            circularProgressView.isHidden = true
            albumImageView.isHidden = false
            title.text = "Canceled!"
        }
    
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    @objc func handleOptionButtonTapped() {
        print("Debug: got tap")
        delegate?.didTapOptionButton(for: self)
    }
    
    /// Call from controller to toggle animation on/off
    func setPlaying(_ isPlaying: Bool) {
        if isPlaying {
            playingIndicator.isHidden = false
            albumImageView.isHidden = true
            playingIndicator.start()
        } else {
            playingIndicator.stop()
            albumImageView.isHidden = false
            playingIndicator.isHidden = true
        }
    }
    
    private func configureThumbnail(for item: DownloadItem) {
        if let url = URL(string: item.thumbURL) {
            // SDWebImage handles caching automatically
                albumImageView.sd_setImage(
                with: url,
                placeholderImage: UIImage(named: "placeholder"),
                options: [.retryFailed, .continueInBackground]
            )
        } else {
            albumImageView.image = UIImage(named: "placeholder")
        }
    }
}


