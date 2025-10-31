//
//  AppSettingsManager.swift
//  ListenUp
//
//  Created by S M H  on 10/10/2025.
//

import Foundation

// MARK: - Settings Manager
final class AppSettingsManager {
    
    // MARK: - Singleton
    static let shared = AppSettingsManager()
    private let defaults = UserDefaults.standard
    
    // MARK: - Settings Keys
    private enum Keys {
        // Network
        static let cellularDataUsage = "settings.network.cellularData"
        
        // Notifications
        static let notificationDownloadComplete = "settings.notification.downloadComplete"
        static let notificationLowStorage = "settings.notification.lowStorage"
        static let notificationUpdates = "settings.notification.updates"
        
        // App State
        static let isFirstLaunch = "settings.app.firstLaunch"
        static let appVersion = "settings.app.version"
        static let lastCacheClearDate = "settings.storage.lastCacheClear"
    }
    
    // MARK: - Notification Names
    static let settingsDidChangeNotification = Notification.Name("AppSettingsDidChange")
    static let cellularDataDidChangeNotification = Notification.Name("CellularDataDidChange")
    
    // MARK: - Initialization
    private init() {
        registerDefaults()
        checkFirstLaunch()
    }
    
    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.cellularDataUsage: false,
            Keys.notificationDownloadComplete: true,
            Keys.notificationLowStorage: true,
            Keys.notificationUpdates: true,
            Keys.isFirstLaunch: true
        ])
    }
    
    private func checkFirstLaunch() {
        if isFirstLaunch {
            defaults.set(false, forKey: Keys.isFirstLaunch)
            if let version = Bundle.main.appVersion {
                defaults.set(version, forKey: Keys.appVersion)
            }
        }
    }
    
    // MARK: - Network Settings
    var isCellularDataEnabled: Bool {
        get { defaults.bool(forKey: Keys.cellularDataUsage) }
        set {
            defaults.set(newValue, forKey: Keys.cellularDataUsage)
            NotificationCenter.default.post(name: Self.cellularDataDidChangeNotification, object: nil)
        }
    }
    
    // MARK: - Notification Settings
    var isDownloadCompleteNotificationEnabled: Bool {
        get { defaults.bool(forKey: Keys.notificationDownloadComplete) }
        set {
            defaults.set(newValue, forKey: Keys.notificationDownloadComplete)
            updateNotificationSettings()
        }
    }
    
    var isLowStorageNotificationEnabled: Bool {
        get { defaults.bool(forKey: Keys.notificationLowStorage) }
        set {
            defaults.set(newValue, forKey: Keys.notificationLowStorage)
            updateNotificationSettings()
        }
    }
    
    var isUpdateNotificationEnabled: Bool {
        get { defaults.bool(forKey: Keys.notificationUpdates) }
        set {
            defaults.set(newValue, forKey: Keys.notificationUpdates)
            updateNotificationSettings()
        }
    }
    
    private func updateNotificationSettings() {
        // Update notification center settings if needed
        NotificationCenter.default.post(name: Self.settingsDidChangeNotification, object: nil)
    }
    
    // MARK: - Storage Management
    var lastCacheClearDate: Date? {
        get { defaults.object(forKey: Keys.lastCacheClearDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastCacheClearDate) }
    }
    
    func clearCache(completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                let cacheContents = try FileManager.default.contentsOfDirectory(
                    at: cacheURL,
                    includingPropertiesForKeys: nil
                )
                
                var clearedSize: Int64 = 0
                for file in cacheContents {
                    let fileSize = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    clearedSize += Int64(fileSize)
                    try FileManager.default.removeItem(at: file)
                }
                
                self.lastCacheClearDate = Date()
                
                let sizeInMB = String(format: "%.2f MB", Double(clearedSize) / 1024 / 1024)
                DispatchQueue.main.async {
                    completion(true, "Successfully cleared \(sizeInMB) of cache")
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Failed to clear cache: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func clearAllData(completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                // Clear Documents
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let documentContents = try FileManager.default.contentsOfDirectory(
                    at: documentsURL,
                    includingPropertiesForKeys: nil
                )
                for file in documentContents {
                    try FileManager.default.removeItem(at: file)
                }
                
                // Clear Cache
                self.clearCache { _, _ in }
                
                // Clear UserDefaults (except critical settings)
                let domain = Bundle.main.bundleIdentifier!
                self.defaults.removePersistentDomain(forName: domain)
                self.defaults.synchronize()
                self.registerDefaults() // Re-register defaults
                
                DispatchQueue.main.async {
                    completion(true, "All app data has been cleared successfully")
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Failed to clear data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - App Info
    var isFirstLaunch: Bool {
        return defaults.bool(forKey: Keys.isFirstLaunch)
    }
    
    var appVersion: String {
        return Bundle.main.appVersion ?? "1.0"
    }
    
    var appBuild: String {
        return Bundle.main.appBuild ?? "1"
    }
}
