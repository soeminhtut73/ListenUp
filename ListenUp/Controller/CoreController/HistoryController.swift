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

class HistoryController: UIViewController {
    
    //MARK: - Properties
    
    private var results: Results<DownloadItem>!
    private var searchResults: Results<DownloadItem>!
    private let searchController = UISearchController(searchResultsController: nil)
    
    private var token: NotificationToken?
    private var progressCache: [ObjectId: Float] = [:]
    
    private var deleteButton: UIBarButtonItem!
    private var selectAllButton: UIBarButtonItem!
    private var cancelButton: UIBarButtonItem!
    
    // MARK: - UI Components
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.separatorStyle = .singleLine
        tv.rowHeight = 64
        tv.register(HistoryTableViewCell.self, forCellReuseIdentifier: HistoryTableViewCell.identifier)
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
    
    // MARK: - Properties
    private var lastPlayingIndexPath: IndexPath?
    private var playerRateKVO: NSKeyValueObservation?
    private var playerItemKVO: NSKeyValueObservation?
    private var notiTokens: [NSObjectProtocol] = []

    //MARK: - LifeCycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        fetchResult()
        setupSearch()
        configureToken()
        startObservingPlayer()
        setupNavigationBar()
        
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }
    
    deinit {
        token?.invalidate()
        playerRateKVO?.invalidate()
        playerItemKVO?.invalidate()
        notiTokens.forEach { NotificationCenter.default.removeObserver($0) }
        NotificationCenter.default.removeObserver(self)
    }
    
    //MARK: - HelperFunctions
    
    private func setupUI() {
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
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
    }
    
    private func configureAudioSession() {
        let s = AVAudioSession.sharedInstance()
        do {
            try s.setCategory(.playback, mode: .moviePlayback, options: [.allowBluetooth,
                                                                         .allowBluetoothA2DP,
                                                                         .allowAirPlay,
                                                                         .mixWithOthers])
            try s.setActive(true)
        } catch { print("Audio session error:", error) }
    }
    
    
    func configureToken() {
        token = results.observe { [weak self] changes in
            guard let self = self else { return }
            switch changes {
            case .initial:
                self.tableView.reloadData()
                
            case .update(_, let deletions, let insertions, let modifications):
                self.tableView.performBatchUpdates({
                    self.tableView.deleteRows(at: deletions.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                    self.tableView.insertRows(at: insertions.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                    self.tableView.reloadRows(at: modifications.map { IndexPath(row: $0, section: 0) }, with: .none)
                })
                
            case .error(let error):
                print("Realm error:", error)
            }
        }
    }
    
    private func setupNavigationBar() {
        let sortButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up.arrow.down"),
            style: .plain,
            target: self,
            action: #selector(sortButtonTapped)
        )
        
        deleteButton = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .done,
            target: self,
            action: #selector(deleteButtonTapped))
        navigationItem.rightBarButtonItems = [deleteButton, sortButton]
        
        selectAllButton = UIBarButtonItem(
            title: "Select All",
            style: .plain,
            target: self,
            action: #selector(selectAllTapped))
        
        cancelButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .done,
            target: self,
            action: #selector(cancelTapped))
    }
    
    private func sortAudioFiles(by keyPath: String, ascending: Bool) {
        searchResults  = searchResults
            .sorted(byKeyPath: keyPath, ascending: ascending)
        
        tableView.reloadData()
    }

    
    func fetchResult() {
        results = RealmService.shared.fetchAllMedia().sorted(byKeyPath: "createdAt", ascending: false)
        searchResults = results
        tableView.reloadData()
    }
    
    func deleteAll() {
        RealmService.shared.deleteAll()
    }
    
    private func showActionSheet(for indexPath: IndexPath) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Delete Action
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) {  _ in
            
        }
        
        // Cancel Action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        actionSheet.addAction(deleteAction)
        actionSheet.addAction(cancelAction)
        
        present(actionSheet, animated: true)
    }
    
    //MARK: - Playing indicator setup
    private func isRowCurrentItem(_ item: DownloadItem) -> Bool {
        guard let playing = PlayerCenter.shared.currentURL?.standardizedFileURL,
              let url = FileHelper.fileURL(for: item.localPath)
        else { return false }
        return url == playing
    }
    
    private func currentItemIndexPath() -> IndexPath? {
        guard let playing = PlayerCenter.shared.currentURL?.standardizedFileURL else { return nil }
        for (row, item) in results.enumerated() {                // results: Results<DownloadItem>
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

    // MARK: - Observe player state

    private func startObservingPlayer() {
        // KVO for play/pause
        playerRateKVO = PlayerCenter.shared.player.observe(\.rate, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.reloadPlayingRows() }
        }

        // KVO for item changes (next/prev/restart/expand)
        playerItemKVO = PlayerCenter.shared.player.observe(\.currentItem, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.reloadPlayingRows() }
        }

        // End-of-item → will switch current item (your code may auto-advance)
        let endTok = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] _ in
            self?.reloadPlayingRows()
        }
        notiTokens.append(endTok)
    }

    
    //MARK: - Selector
    
    @objc func refreshData() {
        tableView.refreshControl?.endRefreshing()
    }
    
    @objc private func onFinished(_ note: Notification) {
        guard let id = note.userInfo?["id"] as? ObjectId else { return }
        progressCache[id] = 1.0
    }
    
    @objc private func appDidBecomeActive() {
        reloadPlayingRows()   // your existing method that reloads old/new playing index paths
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
}

//MARK: - UITableViewDataSource
extension HistoryController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = searchResults[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: HistoryTableViewCell.identifier, for: indexPath) as? HistoryTableViewCell else {
            return UITableViewCell()
        }
        
        cell.configure(with: item)
        let isCurrent = isRowCurrentItem(item)
        cell.setPlaying(isCurrent && PlayerCenter.shared.isActuallyPlaying)   // <- no KVC
        if isCurrent { lastPlayingIndexPath = indexPath }

        
        return cell
    }
}

//MARK: - UITableViewDelegate
extension HistoryController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if tableView.isEditing {
            updateDeleteButtonTitle()
            updateSelectAllButtonTitle()
            return
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let tapped = results[indexPath.row]
        guard let rel = tapped.localPath else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(rel)
        
        MiniPlayerContainerViewController.shared.hide()
        
        let vc = MediaPlayerViewController()
        vc.downloadsResults = searchResults
        vc.startAt(url: url)
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

// MARK: - HistoryTableViewCellDelegate
extension HistoryController: HistoryTableViewCellDelegate {
    func didTapOptionButton(for cell: HistoryTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        showActionSheet(for: indexPath)
    }
}

//MARK: - Setup SearchBar
extension HistoryController: UISearchResultsUpdating, UISearchBarDelegate {
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
    
    func updateSearchResults(for searchController: UISearchController) {
        applySearch(text: searchController.searchBar.text)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        applySearch(text: nil)
    }
    
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
            // search across title and localPath (add more fields if you have them)
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
}

//MARK: - Delete Action
extension HistoryController {
    private var selectionCount: Int {
        tableView.indexPathsForSelectedRows?.count ?? 0
    }
    
    private func enterSelectionMode() {
        tableView.setEditing(true, animated: true)
        navigationItem.leftBarButtonItems = [cancelButton]
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
        deleteButton.title = "Select"
    }
    
    private func updateDeleteButtonTitle() {
        guard tableView.isEditing else { deleteButton.title = "Select"; return }
        deleteButton.title = "Delete (\(selectionCount))"
    }
    
    private func updateSelectAllButtonTitle() {
        guard tableView.isEditing else { return }
        let allSelected = selectionCount == results.count && results.count > 0
        selectAllButton.title = allSelected ? "Deselect All" : "Select All"
        selectAllButton.isEnabled = results.count > 0
    }
    
    @objc private func deleteButtonTapped() {
        if !tableView.isEditing {
            // First press → enter selection mode
            enterSelectionMode()
            return
        }
        
        // Second press → confirm & delete selected rows
        let count = selectionCount
        guard count > 0 else {
            // nothing selected; you can vibrate or simply ignore
            return
        }
        
        let title = count == 1 ? "Delete 1 item?" : "Delete \(count) items?"
        let alert = UIAlertController(title: title,
                                      message: "This will remove them from history.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            // FIXME: - handle to delete
            self?.performDeleteSelected()
        }))
        present(alert, animated: true)
    }
    
    @objc private func selectAllTapped() {
        guard tableView.isEditing else { return }
        let allSelected = selectionCount == results.count && results.count > 0
        
        if allSelected {
            // Deselect all
            if let selected = tableView.indexPathsForSelectedRows {
                for ip in selected {
                    tableView.deselectRow(at: ip, animated: false)
                }
            }
        } else {
            // Select all visible in current filter
            for row in 0..<results.count {
                let ip = IndexPath(row: row, section: 0)
                tableView.selectRow(at: ip, animated: false, scrollPosition: .none)
            }
        }
        updateDeleteButtonTitle()
        updateSelectAllButtonTitle()
    }
    
    private func performDeleteSelected() {
        guard let selected = tableView.indexPathsForSelectedRows else { return }
        
        // Snapshot the objects to delete (Realm Results are live)
        let items: [DownloadItem] = selected
            .map { searchResults[$0.row] }
        
        RealmService.shared.deleteItems(with: items) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.exitSelectionMode()
            case .failure:
                self.showMessage(withTitle: "Oop!", message: "Faield to delete!")
                self.exitSelectionMode()
            }
        }
    }
    
    @objc private func cancelTapped() {
        exitSelectionMode()
    }
}
