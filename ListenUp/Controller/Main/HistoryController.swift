//
//  HistoryController.swift
//  ListenUp
//
//  Created by S M H  on 04/06/2025.
//

import UIKit
import Combine
import RealmSwift
import AVFoundation
import AVKit

final class HistoryController: UIViewController {
    
    // MARK: - Properties
    
    // Data
    private var results: Results<DownloadItem>!
    private var searchResults: Results<DownloadItem>!
    private var token: NotificationToken?
    private var progressCache: [ObjectId: Float] = [:]
    
    // Search
    private let searchController = UISearchController(searchResultsController: nil)
    
    // Navigation Bar Items
    private var deleteButton: UIBarButtonItem!
    private var selectAllButton: UIBarButtonItem!
    private var cancelButton: UIBarButtonItem!
    private var sortButton: UIBarButtonItem!
    
    // Player Observation
    private var lastPlayingIndexPath: IndexPath?
    private var playerRateKVO: NSKeyValueObservation?
    private var playerItemKVO: NSKeyValueObservation?
    private var notiTokens: [NSObjectProtocol] = []
    
    private var isSearching: Bool {
        let raw = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !raw.isEmpty
    }
    
    // MARK: - UI Components
    
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.separatorStyle = .singleLine
        tv.rowHeight = 64
        tv.register(DownloadTableViewCell.self, forCellReuseIdentifier: DownloadTableViewCell.identifier)
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
        setupNavigationBar()
        setupSearch()
        fetchResult()
        configureToken()
        startObservingPlayer()
        setupNotifications()
    }
    
    deinit {
        cleanupObservers()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Library"
        view.backgroundColor = Style.viewBackgroundColor
        
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelectionDuringEditing = true
    }
    
    private func setupNavigationBar() {
        sortButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up.arrow.down"),
            style: .plain,
            target: self,
            action: #selector(sortButtonTapped)
        )
        navigationItem.leftBarButtonItem = sortButton
        
        deleteButton = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .done,
            target: self,
            action: #selector(deleteButtonTapped)
        )
        navigationItem.rightBarButtonItem = deleteButton
        
        selectAllButton = UIBarButtonItem(
            image: UIImage(systemName: "checkmark.circle"),
            style: .plain,
            target: self,
            action: #selector(selectAllTapped)
        )
        
        cancelButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .done,
            target: self,
            action: #selector(cancelTapped)
        )
    }
    
    private func setupSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.placeholder = "Search..."
        searchController.searchBar.delegate = self
        
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    private func cleanupObservers() {
        token?.invalidate()
        playerRateKVO?.invalidate()
        playerItemKVO?.invalidate()
        notiTokens.forEach { NotificationCenter.default.removeObserver($0) }
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Data Management
    
    private func fetchResult() {
        results = RealmService.shared.fetchVideoItems()
            .sorted(byKeyPath: "createdAt", ascending: false)
        searchResults = results
        tableView.reloadData()
    }
    
    func configureToken() {
        token = results.observe { [weak self] changes in
            guard let self = self else { return }
            switch changes {
            case .initial:
                self.updateEmptyState()
                self.tableView.reloadData()
                
            case .update(_, let deletions, let insertions, let modifications):
                if self.isSearching {
                    // re-apply the filter so `searchResults` is updated
                    self.applySearch(text: self.searchController.searchBar.text)
                    self.updateEmptyState()
                    self.tableView.reloadData()
                } else {
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
                    })
                }
                
            case .error(let error):
                print("Realm error:", error)
            }
        }
    }
    
    private func updateEmptyState() {
        emptyStateLabel.isHidden = !results.isEmpty
    }
    
    // MARK: - Audio Session
    
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .moviePlayback,
                options: [
                    .allowBluetoothA2DP,
                    .allowBluetoothHFP,
                    .allowAirPlay,
                    .mixWithOthers
                ]
            )
        } catch {
            print("Audio session error:", error)
        }
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
        
        // Build (AND over tokens) of (OR over fields) predicates
        var andSubpredicates: [NSPredicate] = []
        for tok in tokens {
            // search across title and localPath
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
    
    // MARK: - Playing Indicator
    
    private func isRowCurrentItem(_ item: DownloadItem) -> Bool {
        guard let playing = PlayerCenter.shared.currentURL?.standardizedFileURL,
              let url = FileHelper.fileURL(for: item.localPath)
        else { return false }
        return url == playing
    }
    
    private func currentItemIndexPath() -> IndexPath? {
        guard let playing = PlayerCenter.shared.currentURL?.standardizedFileURL else { return nil }
        for (row, item) in results.enumerated() {
            if let url = FileHelper.fileURL(for: item.localPath), url == playing {
                return IndexPath(row: row, section: 0)
            }
        }
        return nil
    }
    
    private func reloadPlayingRows() {
        let newIdx = currentItemIndexPath()
        var toReload: [IndexPath] = []
        if let old = lastPlayingIndexPath { toReload.append(old) }
        if let new = newIdx { toReload.append(new) }
        toReload = Array(Set(toReload))
        lastPlayingIndexPath = newIdx
        
        guard !toReload.isEmpty else { return }
        tableView.reloadRows(at: toReload, with: .none)
    }
    
    // MARK: - Player Observation
    
    private func startObservingPlayer() {
        // KVO for play/pause
        playerRateKVO = PlayerCenter.shared.player.observe(\.rate, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.reloadPlayingRows() }
        }
        
        // KVO for item changes (next/prev/restart/expand)
        playerItemKVO = PlayerCenter.shared.player.observe(\.currentItem, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.reloadPlayingRows() }
        }
        
        // End-of-item → will switch current item
        let endTok = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadPlayingRows()
        }
        notiTokens.append(endTok)
    }
    
    // MARK: - Action Sheet
    
    private func showActionSheet(for item: DownloadItem) {
//        print("Debug: selected item : \(item.title)")
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Convert action
        let convertAction = UIAlertAction(title: "Convert", style: .default) { _ in
            guard let localPath = item.localPath as String?,
                  let fileURL = FileHelper.fileURL(for: localPath) else { return }
            
            let vc = RingtoneTrimWithStripViewController(videoURL: fileURL, item: item)
            let nav = UINavigationController(rootViewController: vc)
            self.present(nav, animated: true)
        }
        
        // Delete Action
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.showDeleteAlert {
                RealmService.shared.delete(item)
            }
        }
        
        // Cancel Action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        actionSheet.addAction(convertAction)
        actionSheet.addAction(deleteAction)
        actionSheet.addAction(cancelAction)
        
        present(actionSheet, animated: true)
    }
    
    // MARK: - Selection Mode
    
    private var selectionCount: Int {
        tableView.indexPathsForSelectedRows?.count ?? 0
    }
    
    private func enterSelectionMode() {
        tableView.setEditing(true, animated: true)
        navigationItem.leftBarButtonItems = [cancelButton, selectAllButton]
        updateDeleteButtonTitle()
        updateSelectAllButtonTitle()
    }
    
    private func exitSelectionMode() {
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
    
    private func updateDeleteButtonTitle() {
        guard tableView.isEditing else {
            deleteButton.title = "Select"
            return
        }
        deleteButton.title = "Delete (\(selectionCount))"
    }
    
    private func updateSelectAllButtonTitle() {
        guard tableView.isEditing else { return }
        let total = searchResults?.count ?? 0
        let allSelected = selectionCount == total && total > 0
        let imageTitle = allSelected ? "checkmark.circle.fill" : "checkmark.circle"
        selectAllButton.image = UIImage(systemName: imageTitle)
        selectAllButton.isEnabled = results.count > 0
    }
    
    private func performDeleteSelected() {
        guard let selected = tableView.indexPathsForSelectedRows else { return }
        
        // Snapshot the objects to delete (Realm Results are live)
        let items: [DownloadItem] = selected.map { searchResults[$0.row] }
        
        RealmService.shared.deleteItems(with: items) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.exitSelectionMode()
            case .failure:
                self.showMessage(withTitle: "Oops!", message: "Failed to delete!")
                self.exitSelectionMode()
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func appDidBecomeActive() {
        reloadPlayingRows()
    }
    
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
        if !tableView.isEditing {
            // First press → enter selection mode
            enterSelectionMode()
            return
        }
        
        // Second press → confirm & delete selected rows
        let count = selectionCount
        guard count > 0 else { return }
        
        let title = count == 1 ? "Delete 1 item?" : "Delete \(count) items?"
        let alert = UIAlertController(
            title: title,
            message: "This will remove them from history.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDeleteSelected()
        })
        present(alert, animated: true)
    }
    
    @objc private func selectAllTapped() {
        guard tableView.isEditing else { return }
        let total = searchResults?.count ?? 0
        let allSelected = selectionCount == total && total > 0
        
        if allSelected {
            if let selected = tableView.indexPathsForSelectedRows {
                for ip in selected {
                    tableView.deselectRow(at: ip, animated: false)
                }
            }
        } else {
            for row in 0..<total {
                let ip = IndexPath(row: row, section: 0)
                tableView.selectRow(at: ip, animated: false, scrollPosition: .none)
            }
        }
        updateDeleteButtonTitle()
        updateSelectAllButtonTitle()
    }
    
    @objc private func cancelTapped() {
        exitSelectionMode()
    }
}

// MARK: - UITableViewDataSource

extension HistoryController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = searchResults[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: DownloadTableViewCell.identifier,
            for: indexPath
        ) as? DownloadTableViewCell else {
            return UITableViewCell()
        }
        
        cell.delegate = self
        cell.configure(with: item, mode: .video)
        
        let isCurrent = isRowCurrentItem(item)
        cell.setPlaying(isCurrent && PlayerCenter.shared.isActuallyPlaying)
        if isCurrent { lastPlayingIndexPath = indexPath }
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension HistoryController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            updateDeleteButtonTitle()
            updateSelectAllButtonTitle()
            return
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let item = searchResults[indexPath.row]
        guard item.status == .completed else { return }
        
        let tapped = searchResults[indexPath.row]
        guard let rel = tapped.localPath else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(rel)
        
        MiniPlayerContainerViewController.shared.hide()
        
        let vc = MediaPlayerViewController()
        vc.downloadsResults = searchResults
        vc.startAt(url: url, mediaType: item.mediaType)
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            updateDeleteButtonTitle()
            updateSelectAllButtonTitle()
        }
    }
}

// MARK: - UISearchResultsUpdating

extension HistoryController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        applySearch(text: searchController.searchBar.text)
    }
}

// MARK: - UISearchBarDelegate

extension HistoryController: UISearchBarDelegate {
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        applySearch(text: nil)
    }
}

// MARK: - DownloadTableViewCellDelegate

extension HistoryController: DownloadTableViewCellDelegate {
    func cell(_ cell: DownloadTableViewCell, didTapOptionFor item: DownloadItem) {
        showActionSheet(for: item)
    }
}
