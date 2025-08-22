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
    
    func addHistory(url: URL, title: String) {
        let e = HistoryEntry()
        e.url = url.absoluteString
        e.title = title
        e.site = url.host ?? ""
        try? realm.write { realm.add(e) }
    }
    
    func toggleFavorite(url: URL, title: String) {
        let r = realm.objects(FavoriteEntry.self).where { $0.url == url.absoluteString }
        try? realm.write {
            if let f = r.first {
                realm.delete(f)
            } else {
                let f = FavoriteEntry()
                f.url = url.absoluteString
                f.title = title
                f.site = url.host ?? ""
                realm.add(f)
            }
        }
    }

    func getFavorites() -> Results<FavoriteEntry> {
        realm.objects(FavoriteEntry.self).sorted(byKeyPath: "createdAt", ascending: false)
    }
    
    func getHistory() -> Results<HistoryEntry> {
        realm.objects(HistoryEntry.self).sorted(byKeyPath: "createdAt", ascending: false)
    }
    
}
