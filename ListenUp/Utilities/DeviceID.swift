//
//  DeviceID.swift
//  ListenUp
//
//  Created by S M H  on 12/11/2025.
//

import UIKit

final class DeviceID {
    static let shared = DeviceID()
    private let deviceKey = "com.ListenUp.deviceId"

    private init() {}

    func get() -> String {
        if let saved = UserDefaults.standard.string(forKey: deviceKey) {
            return saved
        }

        // 2. try IDFV first
        let newId: String
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            newId = idfv
        } else {
            newId = UUID().uuidString
        }

        UserDefaults.standard.set(newId, forKey: deviceKey)
        return newId
    }
    
    func exists() -> Bool {
        return UserDefaults.standard.string(forKey: deviceKey) != nil
    }
    
    func delete() {
        UserDefaults.standard.removeObject(forKey: deviceKey)
    }
}
