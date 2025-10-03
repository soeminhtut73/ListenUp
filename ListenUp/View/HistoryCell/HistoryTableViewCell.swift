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

protocol HistoryTableViewCellDelegate: AnyObject {
    func didTapOptionButton(for cell: HistoryTableViewCell)
}


class HistoryTableViewCell: UITableViewCell {
    static let identifier = "HistoryTableViewCell"
    
    //MARK: - UIComponent
    
    private let playingIndicator = PlayingIndicatorView()
    
    private let albumImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(systemName: "music.note")
        imageView.tintColor = .secondaryLabel
        imageView.backgroundColor = .clear
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
        button.contentMode = .scaleAspectFit
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.isUserInteractionEnabled = true
        button.addTarget(self, action: #selector(handleOptionButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private let circularProgressView: CircularProgressView = {
        let view = CircularProgressView()
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
        circularProgressView.reset()
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
        [albumImageView, title, optionButton, circularProgressView, playingIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            // Album image
            albumImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            albumImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            albumImageView.widthAnchor.constraint(equalToConstant: 30),
            albumImageView.heightAnchor.constraint(equalToConstant: 30), // square
            
            // Playing indicator (over album)
            playingIndicator.centerXAnchor.constraint(equalTo: albumImageView.centerXAnchor),
            playingIndicator.centerYAnchor.constraint(equalTo: albumImageView.centerYAnchor),
            playingIndicator.widthAnchor.constraint(equalToConstant: 30),
            playingIndicator.heightAnchor.constraint(equalToConstant: 30),
            
            // Circular progress (over album)
            circularProgressView.centerXAnchor.constraint(equalTo: albumImageView.centerXAnchor),
            circularProgressView.centerYAnchor.constraint(equalTo: albumImageView.centerYAnchor),
            circularProgressView.widthAnchor.constraint(equalToConstant: 30),
            circularProgressView.heightAnchor.constraint(equalToConstant: 30),
            
            // Option button
            optionButton.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            optionButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            optionButton.widthAnchor.constraint(equalToConstant: 30),
            optionButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Title label
            title.leadingAnchor.constraint(equalTo: albumImageView.trailingAnchor, constant: 12),
            title.trailingAnchor.constraint(equalTo: optionButton.leadingAnchor, constant: -12),
            title.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        playingIndicator.isHidden = true
    }
    
    // Bind download tasks, 
    func configure(with item: DownloadItem) {
        title.text = item.title
        
        circularProgressView.reset()
        
        switch item.status {
        case.running:
            circularProgressView.isHidden = false
            albumImageView.isHidden = true
            
            DispatchQueue.main.async { [weak self] in
                self?.circularProgressView.isIndeterminate = false
                self?.circularProgressView.setProgress(item.progress, animated: true)
            }
            
        case.completed:
            circularProgressView.isHidden = true
            albumImageView.isHidden = false
            // to load thumbNail after complete
            
        case.failed:
            circularProgressView.isHidden = true
            albumImageView.isHidden = false
            title.text = "Failed to download!"
            title.textColor = .red
            
        case.queued:
            circularProgressView.isHidden = false
            albumImageView.isHidden = true
            circularProgressView.progress = 0
            
        case.canceled:
            circularProgressView.isHidden = true
            albumImageView.isHidden = false
            title.text = "Canceled!"
        }
    
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
}


