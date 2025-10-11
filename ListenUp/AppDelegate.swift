//
//  AppDelegate.swift
//  ListenUp
//
//  Created by S M H  on 04/06/2025.
//

import UIKit
import AVFoundation
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        _ = NetworkMonitor.shared
        
        // Request notification permission
        DownloadNotificationManager.shared.requestNotificationPermission { granted in
            if granted {
                AppSettingsManager.shared.isDownloadCompleteNotificationEnabled = true
            } else {
                AppSettingsManager.shared.isDownloadCompleteNotificationEnabled = false
            }
        }
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        DownloadManager.shared.backgroundCompletionHandler = completionHandler
        
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Called when user taps on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        if response.actionIdentifier == "OPEN_ACTION" {
            // Navigate to downloads screen
            // NotificationCenter.default.post(name: .openDownloads, object: nil)
        }
        
        completionHandler()
    }
}

