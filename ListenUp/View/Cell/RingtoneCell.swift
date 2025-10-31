//
//  RingtoneCell.swift
//  ListenUp
//
//  Created by S M H  on 16/10/2025.
//

import UIKit

class RingtoneCell: UITableViewCell {
    
    private let thumbnailImageView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Add subviews and constraints
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)
        
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbnailImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 60),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 60),
            
            titleLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4)
        ])
        
        thumbnailImageView.layer.cornerRadius = 8
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.contentMode = .scaleAspectFit
        thumbnailImageView.backgroundColor = .systemGray5
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        detailLabel.font = .systemFont(ofSize: 14)
        detailLabel.textColor = .secondaryLabel
        
        accessoryType = .disclosureIndicator
    }
    
    func configure(with ringtone: Ringtone) {
        titleLabel.text = ringtone.title
        detailLabel.text = "\(ringtone.durationFormatted ?? "") | \(ringtone.fileSizeFormatted ?? "")"
        
        // Load thumbnail image
        if let thumbnailUrl = ringtone.thumbnailUrl, let url = URL(string: thumbnailUrl) {
            // Use SDWebImage or similar library
            // thumbnailImageView.sd_setImage(with: url, placeholderImage: UIImage(systemName: "music.note"))
        } else {
            thumbnailImageView.image = UIImage(systemName: "music.note")
        }
    }
}
