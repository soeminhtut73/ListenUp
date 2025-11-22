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
    
    private var didAttachMiniPlayer = false
    private var isInitialized = false
    
    private let maxAllowedDuration: TimeInterval = 10 * 60
    
    // Player Observation
    private var lastObservedRate: Float = 0
    private var playerObservers: [NSKeyValueObservation] = []
    private var cachedPlayingItemId: String?
    
    // Search
    private let searchController = UISearchController(searchResultsController: nil)
    private var searchWorkItem: DispatchWorkItem?
    private var isSearching: Bool {
        let raw = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !raw.isEmpty
    }
    
    // Navigation Bar Items
    private lazy var deleteButton = UIBarButtonItem(
        image: UIImage(systemName: "trash"),
        style: .done,
        target: self,
        action: #selector(deleteButtonTapped)
    )

    private lazy var selectAllButton = UIBarButtonItem(
        image: UIImage(systemName: "checkmark.circle"),
        style: .plain,
        target: self,
        action: #selector(selectAllTapped)
    )

    private lazy var cancelButton = UIBarButtonItem(
        image: UIImage(systemName: "xmark"),
        style: .done,
        target: self,
        action: #selector(cancelTapped)
    )

    private lazy var sortButton = UIBarButtonItem(
        image: UIImage(systemName: "arrow.up.arrow.down"),
        style: .plain,
        target: self,
        action: #selector(sortButtonTapped)
    )
    
    // MARK: - UI Components
    
    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.separatorStyle = .singleLine
        tv.rowHeight = 74
        tv.estimatedRowHeight = 74
        tv.register(DownloadTableViewCell.self, forCellReuseIdentifier: DownloadTableViewCell.identifier)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.contentInsetAdjustmentBehavior = .always
        tv.allowsMultipleSelectionDuringEditing = true
        
        // NEW - Performance optimizations
//        tv.prefetchDataSource = self
//        tv.isPrefetchingEnabled = true
        
        return tv
    }()
    
    private lazy var emptyStateLabel: UILabel = {
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !isInitialized {
            isInitialized = true
            performInitialSetup()
        }
        
        if !didAttachMiniPlayer, let tabBar = tabBarController {
            MiniPlayerController.shared.attach(to: tabBar)
            didAttachMiniPlayer = true
        }
        
        DispatchQueue.main.async { [weak self] in
            MiniPlayerController.shared.show(animated: true)
            self?.reloadPlayingRowsIfNeeded()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchWorkItem?.cancel()
        
        if isMovingFromParent {
            cleanupObservers()
        }
    }
    
    deinit {
        cleanupObservers()
    }
    
    // MARK: - Setup
    
    private func performInitialSetup() {
        fetchResult()
        setupSearch()
        configureToken()
        startObservingPlayer()
        setupNotifications()
    }
    
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
    }
    
    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = sortButton
        navigationItem.rightBarButtonItem = deleteButton
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
        let nc = NotificationCenter.default
        
        nc.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        nc.addObserver(
            self,
            selector: #selector(playerItemChanged),
            name: .playerCenterNextRequested,
            object: nil)
        
        nc.addObserver(
            self,
            selector: #selector(playerItemChanged(_:)),
            name: .playerCenterItemChanged,
            object: nil
        )
    }
    
    private func cleanupObservers() {
        token?.invalidate()
        token = nil
        playerObservers.forEach { $0.invalidate() }
        playerObservers.removeAll()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Data Management
    
    private func fetchResult() {
        results = RealmService.shared.fetchVideoItems()
            .sorted(byKeyPath: "createdAt", ascending: false)
        searchResults = results
        
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    func configureToken() {
        
        token = results.observe { [weak self] changes in
            guard let self = self else { return }
            
            // NEW - Separate handling
            if self.isSearching {
                self.handleSearchResultsUpdate()
                return
            }
            
            self.handleResultsUpdate(changes)
        }
    }
    
    private func handleSearchResultsUpdate() {
        applySearch(text: searchController.searchBar.text)
        updateEmptyState()
    }

    private func handleResultsUpdate(_ changes: RealmCollectionChange<Results<DownloadItem>>) {
        switch changes {
        case .initial:
            self.updateEmptyState()
            self.tableView.reloadData()
            
        case .update(_, let deletions, let insertions, let modifications):
            
            let currentCount = searchResults.count
            let validDeletions = deletions.filter { $0 < currentCount }
            let validInsertions = insertions.filter { $0 < currentCount + validDeletions.count }
            let validModifications = modifications.filter { $0 < currentCount }
            
            guard !validDeletions.isEmpty || !validInsertions.isEmpty || !validModifications.isEmpty else {
                self.updateEmptyState()
                return
            }
            
            self.tableView.performBatchUpdates({
                if !validDeletions.isEmpty {
                    self.tableView.deleteRows(
                        at: validDeletions.map { IndexPath(row: $0, section: 0) },
                        with: .automatic
                    )
                }
                
                if !validInsertions.isEmpty {
                    self.tableView.insertRows(
                        at: validInsertions.map { IndexPath(row: $0, section: 0) },
                        with: .automatic
                    )
                }
                
                if !validModifications.isEmpty {
                    self.tableView.reloadRows(
                        at: validModifications.map { IndexPath(row: $0, section: 0) },
                        with: .none
                    )
                }
            }, completion: { _ in
                self.updateEmptyState()
            })
            
        case .error(let error):
            print("Realm error:", error)
        }
    }
    
    private func updateEmptyState() {
        let isEmpty = (searchResults?.isEmpty ?? true)
        emptyStateLabel.isHidden = !isEmpty
    }
    
    // MARK: - Sorting
    
    private func sortAudioFiles(by keyPath: String, ascending: Bool) {
        searchResults = searchResults.sorted(byKeyPath: keyPath, ascending: ascending)
        tableView.reloadData()
    }
    
    // MARK: - Search
    
    private func applySearch(text: String?) {
        searchWorkItem?.cancel()
        
        let raw = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            searchResults = results
            tableView.reloadData()
            return
        }
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.performSearch(with: raw)
        }
        
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    private func performSearch(with query: String) {
        let tokens = query
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        guard !tokens.isEmpty else {
            searchResults = results
            tableView.reloadData()
            return
        }
        
        let predicates = tokens.map { token in
            NSPredicate(format: "title CONTAINS[c] %@", token)
        }
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        searchResults = results.filter(compoundPredicate)
        tableView.reloadData()
    }
    
    // MARK: - Playing Indicator
    
    private func isItemPlaying(_ item: DownloadItem) -> Bool {
        return PlayerCenter.shared.currentPlayingItemId == item.id
    }
    
    private func reloadPlayingRowsIfNeeded() {
        guard tableView.window != nil else { return }
        
        let currentPlayingId = PlayerCenter.shared.currentPlayingItemId
        
        guard currentPlayingId != cachedPlayingItemId else { return }
        
        cachedPlayingItemId = currentPlayingId
        reloadPlayingRows()
    }
    
    private func reloadPlayingRows() {
        guard tableView.window != nil else { return }
        
        let isPlaying = PlayerCenter.shared.isActuallyPlaying
        
        for cell in tableView.visibleCells {
            guard let playingCell = cell as? DownloadTableViewCell,
                  let indexPath = tableView.indexPath(for: cell),
                  indexPath.row < (searchResults?.count ?? 0) else { continue }
            
            let item = searchResults[indexPath.row]
            let isCurrent = isItemPlaying(item)
            playingCell.setPlaying(isCurrent && isPlaying)
        }
    }
    
    // MARK: - Player Observation
    
    private func startObservingPlayer() {
        let rateObserver = PlayerCenter.shared.player.observe(\.rate, options: [.new]) { [weak self] player, _ in
            guard let self = self else { return }
            
            let newRate = player.rate
            let stateChanged = (self.lastObservedRate > 0) != (newRate > 0)
            
            guard stateChanged else { return }
            
            self.lastObservedRate = newRate
            DispatchQueue.main.async {
                self.reloadPlayingRows()
            }
        }
        
        playerObservers.append(rateObserver)
    }
    
    // MARK: - Action Sheet
    
    private func showActionSheet(for item: DownloadItem) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Convert action
        let convertAction = UIAlertAction(title: "Convert", style: .default) { _ in
            guard let localPath = item.localPath as String?,
                  let fileURL = FileHelper.fileURL(for: localPath) else { return }
            
            guard self.isDurationValid(for: item.duration) else {
                self.showMessage(withTitle: "Oop!", message: "Choose no longer than 10 minutes!")
                return
            }
            
            PlayerCenter.shared.pause()
            let vc = RingtoneTrimWithStripViewController(videoURL: fileURL, item: item)
            let nav = UINavigationController(rootViewController: vc)
            self.present(nav, animated: true)
        }
        
        // Rename action
        let renameAction = UIAlertAction(title: "Rename", style: .default) { _ in
            self.showRenameAlert(currentName: item.title) { newTitle in
                RealmService.shared.update(item.id) { obj in
                    obj.title = newTitle
                }
            }
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
        actionSheet.addAction(renameAction)
        actionSheet.addAction(deleteAction)
        actionSheet.addAction(cancelAction)
        
        present(actionSheet, animated: true)
    }
    
    private func isDurationValid(for duration: TimeInterval) -> Bool {
        return duration >= 0 && duration <= maxAllowedDuration
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
    
    @objc private func playerItemChanged(_ note: Notification) {
        if updateRowsFromNotification(note: note) {
            return
        }
        reloadPlayingRows()
    }
    
    private func updateRowsFromNotification(note: Notification) -> Bool {
        let previousId = note.userInfo?["previousId"] as? String
        let currentId  = note.userInfo?["currentId"] as? String
        
        var didHandle = false
        
        if let previousId, let oldIndexPath = indexPath(forItemId: previousId) {
            if let cell = tableView.cellForRow(at: oldIndexPath) as? DownloadTableViewCell {
                cell.setPlaying(false)
            } else {
                tableView.reloadRows(at: [oldIndexPath], with: .none)
            }
            didHandle = true
        }
        
        // update new row (turn on)
        if let currentId, let newIndexPath = indexPath(forItemId: currentId) {
            if let cell = tableView.cellForRow(at: newIndexPath) as? DownloadTableViewCell {
                cell.setPlaying(PlayerCenter.shared.isActuallyPlaying)
            } else {
                tableView.reloadRows(at: [newIndexPath], with: .none)
            }
            didHandle = true
        }
        return didHandle
    }
    
    private func indexPath(forItemId id: String) -> IndexPath? {
        guard let list = searchResults ?? results else { return nil }
        for (row, item) in list.enumerated() {
            if item.id == id {
                return IndexPath(row: row, section: 0)
            }
        }
        return nil
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
            enterSelectionMode()
            return
        }
        
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
            tableView.performBatchUpdates({
                for row in 0..<total {
                    let ip = IndexPath(row: row, section: 0)
                    tableView.selectRow(at: ip, animated: false, scrollPosition: .none)
                }
            })
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
        
        let isCurrent = isItemPlaying(item)
        cell.setPlaying(isCurrent && PlayerCenter.shared.isActuallyPlaying)
        
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
        guard item.status == .completed, let url = item.localPath else { return }
        let fileURL = FileHelper.fileURL(for: url)
        
        PlayerCenter.shared.setCurrentPlayingItem(id: item.id)
        
        let vc = MediaPlayerViewController()
        vc.downloadsResults = searchResults
        vc.startAt(url: fileURL, mediaType: item.mediaType)
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
        reloadPlayingRows()
    }
}

// MARK: - DownloadTableViewCellDelegate

extension HistoryController: DownloadTableViewCellDelegate {
    func cell(_ cell: DownloadTableViewCell, didTapOptionFor item: DownloadItem) {
        showActionSheet(for: item)
    }
}

//MARK: - MiniPlayerAdjustable Delegate

extension HistoryController: MiniPlayerAdjustable {
    func setMiniPlayerVisible(_ visible: Bool, height: CGFloat) {
        var inset = tableView.contentInset
        inset.bottom = visible ? height : 0
        tableView.contentInset = inset
        tableView.scrollIndicatorInsets = inset
    }
}
