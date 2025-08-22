//
//  Style.swift
//  ListenUp
//
//  Created by S M H  on 07/06/2025.
//

import UIKit

struct Style {
    
    // MARK: – Fonts
    static let titleFont: UIFont     = .systemFont(ofSize: 24, weight: .bold)
    static let bodyFont: UIFont      = .systemFont(ofSize: 16, weight: .regular)
    static let captionFont: UIFont   = .systemFont(ofSize: 12, weight: .light)
    
    // MARK: – Font Colors
    static let primaryTextColor: UIColor   = .black
    static let secondaryTextColor: UIColor = .darkGray
    static let accentTextColor: UIColor    = UIColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1.0)
    
    // MARK: – Background Colors
    static let viewBackgroundColor: UIColor       = UIColor(hex: "#E5E5E5")
    static let textFieldBackgroundColor: UIColor  = .white
    
    // MARK: – TextField Styles
    static let textFieldCornerRadius: CGFloat = 8
    static let textFieldBorderColor: UIColor  = UIColor(white: 0.8, alpha: 1.0)
    static let textFieldBorderWidth: CGFloat  = 1
}

