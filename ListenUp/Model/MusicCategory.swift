//
//  MusicCategory.swift
//  ListenUp
//
//  Created by S M H  on 16/10/2025.
//

import UIKit

struct MusicCategory: Codable, Identifiable {
    let id: Int
    let name: String
    let icon: String?
    let ringtonesCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, icon
        case ringtonesCount = "ringtones_count"
    }
}
