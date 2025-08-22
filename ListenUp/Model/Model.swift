//
//  Model.swift
//  ListenUp
//
//  Created by S M H  on 18/08/2025.
//

import UIKit
import RealmSwift

class HistoryEntry: Object {
  @Persisted(primaryKey: true) var id: ObjectId
  @Persisted var url: String = ""
  @Persisted var title: String = ""
  @Persisted var site: String = ""
  @Persisted var createdAt: Date = Date()
}

class FavoriteEntry: Object {
  @Persisted(primaryKey: true) var id: ObjectId
  @Persisted var url: String = ""
  @Persisted var title: String = ""
  @Persisted var site: String = ""
  @Persisted var createdAt: Date = Date()
}
