//
//  ActionSheetConfigurable.swift
//  ListenUp
//
//  Created by S M H  on 26/10/2025.
//

import UIKit

protocol ActionSheetConfigurable: AnyObject {
    func configureActions(for item: DownloadItem) -> [UIAlertAction]
}

extension ActionSheetConfigurable where Self: UIViewController {
    
    func showActionSheet(for item: DownloadItem) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Get custom actions from conforming controller
        let actions = configureActions(for: item)
        actions.forEach { actionSheet.addAction($0) }
        
        // Always add cancel
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        actionSheet.addAction(cancelAction)
        
        present(actionSheet, animated: true)
    }
}
