//
//  Ringtone.swift
//  ListenUp
//
//  Created by S M H  on 16/10/2025.
//

import UIKit

struct Ringtone: Codable, Identifiable {
    let id: Int
    let title: String
    let slug: String
    let description: String?
    let category: RingtoneCategory?
    let fileUrl: String?
    let fileName: String?
    let fileFormat: String?
    let fileSize: Int?
    let fileSizeFormatted: String?
    let duration: Int?
    let durationFormatted: String?
    let thumbnailUrl: String?
    let downloadCount: Int
    let playCount: Int
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, slug, description, category
        case fileUrl = "file_url"
        case fileName = "file_name"
        case fileFormat = "file_format"
        case fileSize = "file_size"
        case fileSizeFormatted = "file_size_formatted"
        case duration
        case durationFormatted = "duration_formatted"
        case thumbnailUrl = "thumbnail_url"
        case downloadCount = "download_count"
        case playCount = "play_count"
        case createdAt = "created_at"
    }
    
    struct RingtoneCategory: Codable {
        let id: Int
        let name: String
    }
}
