//
//  RealmService.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import Foundation
import RealmSwift

@MainActor
class RealmService: ObservableObject, Alertable, Loggable {
    static let shared = RealmService()
    init() { print("init RealmService") }
    deinit { print("deinit RealmService") }
}

class RealmCache: Object {
    @Persisted(primaryKey: true) var id: String
    @Persisted var data: String = ""
    @Persisted var collection: String = ""
    
    convenience init(id: String, data: String, collection: String) {
        self.init()
        self.id = id
        self.data = data
        self.collection = collection
    }
}

class RealmImage: Object {
    @Persisted(primaryKey: true) var id: String
    @Persisted var data: String = ""
    
    convenience init(id: String, data: String) {
        self.init()
        self.id = id
        self.data = data
    }
}
