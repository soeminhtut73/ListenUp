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
    
    private let albumImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(systemName: "music.note")
        imageView.tintColor = .secondaryLabel
        imageView.backgroundColor = .clear
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        circularProgressView.reset()
    }

    
    private func setupUI() {
        contentView.addSubview(albumImageView)
        contentView.addSubview(title)
        contentView.addSubview(optionButton)
        contentView.addSubview(circularProgressView)
        
        albumImageView.anchor(left: leftAnchor, paddingLeft: 16, width: 30, height: 30)
        albumImageView.centerY(inView: self)
        
        circularProgressView.centerX(inView: albumImageView)
        circularProgressView.centerY(inView: albumImageView)
        circularProgressView.setDimensions(height: 30, width: 30)
        
        optionButton.anchor(right: rightAnchor, paddingRight: 16, width: 30, height: 30)
        optionButton.centerY(inView: self)
        
        title.centerY(inView: albumImageView)
        title.anchor(left: albumImageView.rightAnchor, right: optionButton.leftAnchor, paddingLeft: 12, paddingRight: 12)
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
    
    // MARK: - Helpers
}


