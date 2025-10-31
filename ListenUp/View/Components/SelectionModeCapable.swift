//
//  SelectionModeCapable.swift
//  ListenUp
//
//  Created by S M H  on 26/10/2025.
//

import UIKit
import RealmSwift

protocol SelectionModeCapable: AnyObject {
    var tableView: UITableView { get }
    var navigationItem: UINavigationItem { get }
    var deleteButton: UIBarButtonItem { get }
    var cancelButton: UIBarButtonItem { get }
    var selectAllButton: UIBarButtonItem { get }
    var sortButton: UIBarButtonItem { get }
    
    // Data source
    func getItems() -> Results<DownloadItem>
    func getItemAt(indexPath: IndexPath) -> DownloadItem
    
    // Deletion
    func deleteItems(_ items: [DownloadItem], completion: @escaping (Result<Void, Error>) -> Void)
    
    // Optional customization points
    func willEnterSelectionMode()
    func didExitSelectionMode()
    func customizeDeleteAlert(count: Int) -> (title: String, message: String)
}

// MARK: - Default Implementations
extension SelectionModeCapable where Self: UIViewController {
    
    var selectionCount: Int {
        tableView.indexPathsForSelectedRows?.count ?? 0
    }
    
    // MARK: - Selection Mode
    func enterSelectionMode() {
        willEnterSelectionMode()
        tableView.setEditing(true, animated: true)
        navigationItem.leftBarButtonItems = [cancelButton, selectAllButton]
        updateSelectAllButtonTitle()
    }
    
    func exitSelectionMode() {
        // Clear visual selections
        if let selected = tableView.indexPathsForSelectedRows {
            for ip in selected {
                tableView.deselectRow(at: ip, animated: false)
            }
        }
        tableView.setEditing(false, animated: true)
        navigationItem.leftBarButtonItem = sortButton
        deleteButton.title = "Select"
        didExitSelectionMode()
    }
    
    func updateSelectAllButtonTitle() {
        guard tableView.isEditing else { return }
        let items = getItems()
        let allSelected = selectionCount == items.count && items.count > 0
        let imageTitle = allSelected ? "checkmark.circle.fill" : "checkmark.circle"
        selectAllButton.image = UIImage(systemName: imageTitle)
        selectAllButton.isEnabled = items.count > 0
    }
    
    // MARK: - Actions
    func handleDeleteButtonTapped() {
        if !tableView.isEditing {
            enterSelectionMode()
            return
        }
        
        let count = selectionCount
        guard count > 0 else { return }
        
        let alertInfo = customizeDeleteAlert(count: count)
        let alert = UIAlertController(
            title: alertInfo.title,
            message: alertInfo.message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDeleteSelected()
        })
        present(alert, animated: true)
    }
    
    func handleSelectAllTapped() {
        guard tableView.isEditing else { return }
        let items = getItems()
        let allSelected = selectionCount == items.count && items.count > 0
        
        if allSelected {
            // Deselect all
            if let selected = tableView.indexPathsForSelectedRows {
                for ip in selected {
                    tableView.deselectRow(at: ip, animated: false)
                }
            }
        } else {
            // Select all
            for row in 0..<items.count {
                let ip = IndexPath(row: row, section: 0)
                tableView.selectRow(at: ip, animated: false, scrollPosition: .none)
            }
        }
        updateSelectAllButtonTitle()
    }
    
    func handleCancelTapped() {
        exitSelectionMode()
    }
    
    private func performDeleteSelected() {
        guard let selected = tableView.indexPathsForSelectedRows else { return }
        
        let items: [DownloadItem] = selected.map { getItemAt(indexPath: $0) }
        deleteItems(items) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.exitSelectionMode()
            case .failure:
                self.showErrorAlert(title: "Oops!", message: "Failed to delete!")
                self.exitSelectionMode()
            }
        }
    }
    
    // MARK: - Default Implementations (can be overridden)
    func willEnterSelectionMode() {
        tableView.setEditing(true, animated: true)
        navigationItem.leftBarButtonItems = [cancelButton, selectAllButton]
        updateSelectAllButtonTitle()
    }
    
    func didExitSelectionMode() {
        // Clear visual selections
        if let selected = tableView.indexPathsForSelectedRows {
            for ip in selected {
                tableView.deselectRow(at: ip, animated: false)
            }
        }
        tableView.setEditing(false, animated: true)
        navigationItem.leftBarButtonItem = nil
        navigationItem.leftBarButtonItem = sortButton
    }
    
    func customizeDeleteAlert(count: Int) -> (title: String, message: String) {
        let title = count == 1 ? "Delete 1 item?" : "Delete \(count) items?"
        return (title, "This will remove them from history.")
    }
    
    // Helper
    private func showErrorAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

