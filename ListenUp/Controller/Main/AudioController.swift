//
//  AudioController.swift
//  ListenUp
//
//  Created by S M H  on 25/10/2025.
//

import UIKit
import RealmSwift

class AudioController: UIViewController {
    
    // MARK: - Properties
    
    // Data
    private var results: Results<DownloadItem>!
    private var searchResults: Results<DownloadItem>!
    private var notificationToken: NotificationToken?
    
    // Search
    private let searchController = UISearchController(searchResultsController: nil)
    
    // Navigation Bar Items
    internal lazy var sortButton = UIBarButtonItem(
        image: UIImage(systemName: "arrow.up.arrow.down"),
        style: .plain,
        target: self,
        action: #selector(sortButtonTapped)
    )
    
    internal lazy var deleteButton = UIBarButtonItem(
        image: UIImage(systemName: "trash"),
        style: .done,
        target: self,
        action: #selector(deleteButtonTapped)
    )
    
    internal lazy var selectAllButton = UIBarButtonItem(
        image: UIImage(systemName: "checkmark.circle"),
        style: .plain,
        target: self,
        action: #selector(selectAllTapped)
    )
    
    internal lazy var cancelButton = UIBarButtonItem(
        image: UIImage(systemName: "xmark"),
        style: .done,
        target: self,
        action: #selector(cancelTapped)
    )
    
    // MARK: - UI Components
    
    private(set) lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.separatorStyle = .singleLine
        tv.rowHeight = 64
        tv.register(
            DownloadTableViewCell.self,
            forCellReuseIdentifier: DownloadTableViewCell.identifier
        )
        tv.allowsMultipleSelectionDuringEditing = true
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No downloads yet"
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 18)
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSearch()
        fetchResult()
        observeRealmChanges()
    }
    
    deinit {
        notificationToken?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Tones"
        view.backgroundColor = Style.viewBackgroundColor
        
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelectionDuringEditing = true
        
        navigationItem.rightBarButtonItem = deleteButton
        navigationItem.leftBarButtonItem = sortButton
    }
    
    private func setupSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.placeholder = "Search Tone..."
        searchController.searchBar.delegate = self
        
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }
    
    // MARK: - Data Management
    
    private func fetchResult() {
        results = RealmService.shared.fetchAudioItems()
            .sorted(byKeyPath: "createdAt", ascending: false)
        searchResults = results
        tableView.reloadData()
    }
    
    private func observeRealmChanges() {
        notificationToken = searchResults.observe { [weak self] changes in
            guard let self = self else { return }
            switch changes {
            case .initial:
                self.updateEmptyState()
                self.tableView.reloadData()
                
            case .update(_, let deletions, let insertions, let modifications):
                self.tableView.performBatchUpdates({
                    self.tableView.deleteRows(
                        at: deletions.map { IndexPath(row: $0, section: 0) },
                        with: .automatic
                    )
                    self.tableView.insertRows(
                        at: insertions.map { IndexPath(row: $0, section: 0) },
                        with: .automatic
                    )
                    self.tableView.reloadRows(
                        at: modifications.map { IndexPath(row: $0, section: 0) },
                        with: .none
                    )
                    self.updateEmptyState()
                })
                
                if self.tableView.isEditing {
                    self.updateSelectAllButtonTitle()
                }
                
            default:
                break
            }
        }
    }
    
    private func updateEmptyState() {
        emptyStateLabel.isHidden = !results.isEmpty
    }
    
    // MARK: - Sorting
    
    private func sortAudioFiles(by keyPath: String, ascending: Bool) {
        searchResults = searchResults.sorted(byKeyPath: keyPath, ascending: ascending)
        tableView.reloadData()
    }
    
    // MARK: - Search
    
    private func applySearch(text: String?) {
        let raw = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            searchResults = results
            tableView.reloadData()
            return
        }
        
        // Split into tokens by spaces; ignore empties
        let tokens = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        var andSubpredicates: [NSPredicate] = []
        for tok in tokens {
            let orForToken = NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "title CONTAINS[c] %@", tok)
            ])
            andSubpredicates.append(orForToken)
        }
        
        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: andSubpredicates)
        
        // Filter from the full, already-sorted Results
        searchResults = results.filter(compound)
        
        tableView.reloadData()
    }
    
    // MARK: - Helper Methods
    
    private func shareAudio(_ item: DownloadItem) {
        guard let localPath = item.localPath,
              let fileURL = FileHelper.fileURL(for: localPath) else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        present(activityVC, animated: true)
    }
    
    private func showDeleteConfirmation(for item: DownloadItem) {
        let alert = UIAlertController(
            title: "Delete Audio",
            message: "This will remove it permanently.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            RealmService.shared.delete(item)
        })
        present(alert, animated: true)
    }
    
    // MARK: - Actions
    
    @objc private func sortButtonTapped() {
        let alert = UIAlertController(title: "Sort By", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Newest First", style: .default) { [weak self] _ in
            self?.sortAudioFiles(by: "createdAt", ascending: false)
        })
        
        alert.addAction(UIAlertAction(title: "Oldest First", style: .default) { [weak self] _ in
            self?.sortAudioFiles(by: "createdAt", ascending: true)
        })
        
        alert.addAction(UIAlertAction(title: "Name (A-Z)", style: .default) { [weak self] _ in
            self?.sortAudioFiles(by: "title", ascending: true)
        })
        
        alert.addAction(UIAlertAction(title: "Name (Z-A)", style: .default) { [weak self] _ in
            self?.sortAudioFiles(by: "title", ascending: false)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc private func deleteButtonTapped() {
        handleDeleteButtonTapped()
    }
    
    @objc private func selectAllTapped() {
        handleSelectAllTapped()
    }
    
    @objc private func cancelTapped() {
        handleCancelTapped()
    }
}

// MARK: - UITableViewDataSource

extension AudioController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: DownloadTableViewCell.identifier,
            for: indexPath
        ) as! DownloadTableViewCell
        
        let item = searchResults[indexPath.row]
        cell.configure(with: item, mode: .audio)
        cell.delegate = self
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension AudioController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            updateSelectAllButtonTitle()
            return
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
        guard !tableView.isEditing else {
            updateSelectAllButtonTitle()
            return
        }
        
        let item = searchResults[indexPath.row]
        guard item.status == .completed else { return }
        
        let tapped = searchResults[indexPath.row]
        guard let rel = tapped.localPath else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(rel)
        
//        MiniPlayerContainerViewController.shared.hide()
        
        let vc = MediaPlayerViewController()
        vc.downloadsResults = searchResults
        vc.startAt(url: url, mediaType: item.mediaType)
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard tableView.isEditing else { return }
        updateSelectAllButtonTitle()
    }
}

// MARK: - UISearchResultsUpdating

extension AudioController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        applySearch(text: searchController.searchBar.text)
    }
}

// MARK: - UISearchBarDelegate

extension AudioController: UISearchBarDelegate {
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        applySearch(text: nil)
    }
}

// MARK: - DownloadTableViewCellDelegate

extension AudioController: DownloadTableViewCellDelegate {
    func cell(_ cell: DownloadTableViewCell, didTapOptionFor item: DownloadItem) {
        showActionSheet(for: item)
    }
}

// MARK: - SelectionModeCapable

extension AudioController: SelectionModeCapable {
    
    func getItems() -> Results<DownloadItem> {
        return searchResults
    }
    
    func getItemAt(indexPath: IndexPath) -> DownloadItem {
        return searchResults[indexPath.row]
    }
    
    func deleteItems(_ items: [DownloadItem], completion: @escaping (Result<Void, Error>) -> Void) {
        RealmService.shared.deleteItems(with: items, completion: completion)
    }
    
    func customizeDeleteAlert(count: Int) -> (title: String, message: String) {
        let title = count == 1 ? "Delete 1 audio?" : "Delete \(count) audios?"
        return (title, "This will permanently remove them.")
    }
}

// MARK: - ActionSheetConfigurable

extension AudioController: ActionSheetConfigurable {
    
    func configureActions(for item: DownloadItem) -> [UIAlertAction] {
        var actions: [UIAlertAction] = []
        
        // Share Action
        let shareAction = UIAlertAction(title: "Share", style: .default) { [weak self] _ in
            self?.shareAudio(item)
        }
        actions.append(shareAction)
        
        let renameAction = UIAlertAction(title: "Rename", style: .default) { _ in
            self.showRenameAlert(currentName: item.title) { newTitle in
                RealmService.shared.update(item.id) { obj in
                    obj.title = newTitle
                }
            }
        }
        actions.append(renameAction)
        
        // Delete Action
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.showDeleteConfirmation(for: item)
        }
        actions.append(deleteAction)
        
        return actions
    }
}
