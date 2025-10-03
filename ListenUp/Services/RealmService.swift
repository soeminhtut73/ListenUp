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
    private var realm: Realm { try! Realm() }
    
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
    
    func delete(_ model: DownloadItem) {
        try? realm.write {
            if let videoPath = model.localPath {
                try? FileManager.default.removeItem(atPath: videoPath)
            }
            
//            if let audioPath = model.localAudioPath {
//                try? FileManager.default.removeItem(atPath: audioPath)
//            }
            realm.delete(model)
        }
    }
    
    func deleteItems(with items: [DownloadItem], completion: @escaping (Result<Void, Error>) -> Void) {
        
        let fileURLs: [URL] = items.compactMap { FileHelper.fileURL(for: $0.localPath) }
    
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
    
    func deleteAll() {
        try? realm.write {
            realm.deleteAll()
        }
    }
    
    
}
