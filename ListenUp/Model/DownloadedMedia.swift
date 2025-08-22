//
//  DownloadedMedia.swift
//  ListenUp
//
//  Created by S M H  on 18/07/2025.
//

import Foundation
import RealmSwift

class DownloadedMedia: Object {
    @Persisted var id = UUID().uuidString
    @Persisted var fileName: String = ""
    @Persisted var fileURL: String = ""
    @Persisted var sourceURL: String = ""
    @Persisted var downloadDate: Date = Date()
    @Persisted var fileSize: Int64 = 0
    @Persisted var mediaType: String = ""
    
    override static func primaryKey() -> String? {
        return "id"
    }
}
