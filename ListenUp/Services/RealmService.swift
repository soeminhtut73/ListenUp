//
//  RealmServices.swift
//  ListenUp
//
//  Created by S M H  on 18/07/2025.
//

import Foundation
import RealmSwift

class RealmService {
    
    static let shared = RealmService()
    var realm: Realm {
        do {
            return try Realm()
        } catch {
            fatalError("Failed to open main Realm: \(error)")
        }
    }
    
    private init() {}
    
    func createOrUpdate(item: DownloadItem) {
        try? realm.write {
            realm.add(item, update: .modified)
        }
    }
    
    func update(_ id: String, _ changes: (DownloadItem) -> Void) {
        guard let obj = realm.object(ofType: DownloadItem.self, forPrimaryKey: id) else { return }
        try? realm.write {
            changes(obj)
        }
    }
    
    func fetchAllMedia() -> Results<DownloadItem> {
        realm.objects(DownloadItem.self).sorted(byKeyPath: "createdAt", ascending: false)
    }
    
    // Fetch only video items (for HistoryViewController)
    func fetchVideoItems() -> Results<DownloadItem> {
        realm.objects(DownloadItem.self)
            .filter("mediaType == %@ OR mediaType == %@", MediaType.video.rawValue)
            .sorted(byKeyPath: "createdAt", ascending: false)
    }
    
    // Fetch only audio items (for AudioViewController)
    func fetchAudioItems() -> Results<DownloadItem> {
        realm.objects(DownloadItem.self)
            .filter("mediaType == %@ OR mediaType == %@", MediaType.audio.rawValue)
            .sorted(byKeyPath: "createdAt", ascending: false)
    }
    
    func delete(_ model: DownloadItem) {
        try? realm.write {
            if let videoPath = model.localPath {
                let videoURL = FileHelper.fileURL(for: videoPath)
                if let url = videoURL {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            print("Debug: Delete successfully.")
            realm.delete(model)
        }
    }
    
    func deleteItems(with items: [DownloadItem], completion: @escaping (Result<Void, Error>) -> Void) {
        
        // Collect both video and audio file URLs
        var fileURLs: [URL] = []
        
        for item in items {
            if let videoPath = item.localPath,
               let videoURL = FileHelper.fileURL(for: videoPath) {
                fileURLs.append(videoURL)
            }
        }
        
        do {
            try realm.write {
                realm.delete(items)
            }
            
            for url in fileURLs {
                try? FileManager.default.removeItem(at: url)
            }
            
            DispatchQueue.main.async {
                completion(.success(()))
            }
            
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
    
    // Delete only video file but keep the audio
    func deleteVideoOnly(for id: String) {
        update(id) { item in
            if let videoPath = item.localPath {
                let videoURL = FileHelper.fileURL(for: videoPath)
                if let url = videoURL {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            item.localPath = nil
            item.fileSize = 0
        }
    }
    
    
    
    func deleteAll() {
        try? realm.write {
            realm.deleteAll()
        }
    }
    
    
}
