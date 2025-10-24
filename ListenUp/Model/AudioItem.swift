//
//  AudioItem.swift
//  ListenUp
//
//  Created by S M H  on 23/10/2025.
//

import RealmSwift

final class AudioItem: Object {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var title: String
    @Persisted var localAudioPath: String?
    @Persisted var audioFileSize: Int64 = 0
    @Persisted var duration: Double = 0
    @Persisted var audioConversionDate: Date?
}

