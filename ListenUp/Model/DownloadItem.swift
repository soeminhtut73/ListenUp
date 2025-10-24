//
//  DownloadItem.swift
//  ListenUp
//
//  Created by S M H  on 04/09/2025.
//

import Foundation
import RealmSwift

enum MediaType: Int, PersistableEnum {
    case video = 0 // video
    case audio = 1 // ringtone
}


enum DLStatus: Int, PersistableEnum {
    case queued = 0, running, completed, failed, canceled
}
final class DownloadItem: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString

    @Persisted var title: String = ""
    @Persisted var sourceURL: String = ""        // the extract (googlevideo) URL you started with
    @Persisted var thumbURL: String = ""         // optional
    @Persisted var localPath: String?
    @Persisted var status: DLStatus = .queued
    @Persisted var progress: Double = 0          // 0...1
    @Persisted var fileSize: Int64 = 0
    @Persisted var createdAt: Date = Date()
    @Persisted var errorMessage: String?
    
    @Persisted var mediaType: MediaType = .video
    @Persisted var duration: TimeInterval = 0       // For displaying length
    @Persisted var format: String = ""
}
