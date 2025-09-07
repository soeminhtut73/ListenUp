//
//  MediaModel.swift
//  ListenUp
//
//  Created by S M H  on 04/08/2025.
//

import UIKit
import RealmSwift

class MediaModel: Object {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var title: String
    @Persisted var createdAt: Date = Date()
    @Persisted var originalURL: String
    @Persisted var localVideoPath: String?   // saved video file
    @Persisted var localAudioPath: String?   // saved audio file (m4a)
    @Persisted var fileSizeBytes: Int64      // size of the *video* file
    @Persisted var mediaType: String         // "video" | "audio"
    @Persisted var thumbnail: String?         // "video" | "audio"
}
