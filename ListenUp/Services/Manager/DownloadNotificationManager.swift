//
//  DownloadNotificationManager.swift
//  ListenUp
//
//  Created by S M H  on 11/10/2025.
//

import UIKit
import UserNotifications

class DownloadNotificationManager {
    static let shared = DownloadNotificationManager()
    
    private init() {}
    
    // Request permission once at app launch
    func requestNotificationPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    // System notification (works in background)
    func showSystemNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.body = "Media has been saved to your library"
        content.sound = .default
        
        // Optional: Add action buttons
        let openAction = UNNotificationAction(
            identifier: "OPEN_ACTION",
            title: "Open",
            options: .foreground
        )
        
        let category = UNNotificationCategory(
            identifier: "DOWNLOAD_COMPLETE",
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "DOWNLOAD_COMPLETE"
        
        // Deliver immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to show notification: \(error)")
            }
        }
    }
}


