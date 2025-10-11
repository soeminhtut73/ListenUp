//
//  DownloadGuard.swift
//  ListenUp
//
//  Created by S M H  on 10/10/2025.
//

import UIKit

enum DownloadGuard {
    enum DownloadDecision {
        case proceed
        case cancelled
    }
    
    /// Call from your "Start Download" button.
    static func checkAndProceed(from presenter: UIViewController,
                                proceed: @escaping (DownloadDecision) -> Void) {
        
        let manager = AppSettingsManager.shared
        let monitor = NetworkMonitor.shared
        let networkType = monitor.connectionType
        
        // Check 2: WiFi - always proceed
        if networkType == .wifi {
            proceed(.proceed)
            return
        }
    
        // Check 3: Cellular - check settings
        if networkType == .wifi {
            if manager.isCellularDataEnabled {
                // Cellular enabled - proceed
                proceed(.proceed)
            } else {
                // Cellular NOT enabled - ask user
                showCellularConfirmationAlert(from: presenter, proceed: proceed)
            }
            return
        }
        
        // Fallback for unknown connection types
        proceed(.proceed)
    }
    
    private static func showCellularConfirmationAlert(from presenter: UIViewController,
                                                      proceed: @escaping (DownloadDecision) -> Void) {
        let ac = UIAlertController(
            title: "Use Cellular Data?",
            message: "Cellular data for downloads is disabled. Download anyway?",
            preferredStyle: .alert
        )
        
        ac.addAction(UIAlertAction(title: "Download", style: .default) { _ in
            proceed(.proceed)
        })
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            proceed(.cancelled)
        })
        
        presenter.present(ac, animated: true)
    }
}
