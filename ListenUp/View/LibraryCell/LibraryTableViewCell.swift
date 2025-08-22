//
//  LibraryTableViewCell.swift
//  ListenUp
//
//  Created by S M H  on 07/06/2025.
//

import UIKit

class LibraryTableViewCell: UITableViewCell {
    
    //MARK: - Properties
    
    private let albumImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(systemName: "music.note")
        imageView.layer.cornerRadius = 8
        return imageView
    }()
    
    private let albumNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.numberOfLines = 0
        label.text = "Machine Gun Kelly"
        label.textColor = .label
        return label
    }()
    
    private let optionButton: UIButton = {
        let button = UIButton(type: .system)
        button.contentMode = .scaleAspectFit
        button.setBackgroundImage(UIImage(systemName: "ellipsis"), for: .normal)
        return button
    }()
    
    //MARK: - Lifecycle
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        
        addSubview(albumImageView)
        albumImageView.centerY(inView: self, leftAnchor: leftAnchor, paddingLeft: 16)
        albumImageView.setDimensions(height: 30, width: 30)
        
        addSubview(optionButton)
        optionButton.centerY(inView: self, rightAnchor: rightAnchor, paddingRight: 16)
        optionButton.setDimensions(height: 10, width: 15)
        
        addSubview(albumNameLabel)
        albumNameLabel.centerY(inView: self, leftAnchor: albumImageView.rightAnchor, rightAnchor: optionButton.leftAnchor, paddingLeft: 12, paddingRight: 12)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - HelperFunctions
}
