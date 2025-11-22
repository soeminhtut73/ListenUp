//
//  AudioController.swift
//  ListenUp
//
//  Created by S M H  on 25/10/2025.
//

import UIKit
import RealmSwift
import AVFoundation

class AudioController: UIViewController {
    
    // MARK: - Properties
    
    // Data
    private var results: Results<DownloadItem>!
    private var searchResults: Results<DownloadItem>!
    private var tokens: NotificationToken?
    
    // Search
    private let searchController = UISearchController(searchResultsController: nil)
    private var searchWorkItem: DispatchWorkItem?
    private var isSearching: Bool {
        let raw = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !raw.isEmpty
    }
    
    // Player Observation
    private var lastObservedRate: Float = 0
    private var playerObservers: [NSKeyValueObservation] = []
    private var cachedPlayingItemId: String?
    
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
        setupSearch()
        
        DispatchQueue.main.async { [weak self] in
            self?.performInitialSetup()
        }
        
        startObservingPlayer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let tabBar = self.tabBarController {
            MiniPlayerController.shared.attach(to: tabBar)
        }
        
        if tableView.window != nil {
            reloadPlayingRows()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchWorkItem?.cancel()
    }
    
    deinit {
        tokens?.invalidate()
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
    
    private func performInitialSetup() {
        fetchResult()
        configureToken()
        startObservingPlayer()
        setupNotifications()
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
    
    private func setupNotifications() {
        let nc = NotificationCenter.default
        
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
    
    func configureToken() {
        
        tokens = results.observe { [weak self] changes in
            guard let self = self else { return }
            
            if self.isSearching {
                self.applySearch(text: self.searchController.searchBar.text)
                self.updateEmptyState()
                return
            }
            
            switch changes {
            case .initial:
                self.updateEmptyState()
                self.tableView.reloadData()
                
            case .update(_, let deletions, let insertions, let modifications):
                let currentCount = searchResults.count
                
                // Validate indices
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
    }
    
    // MARK: - Data Management
    
    private func fetchResult() {
        results = RealmService.shared.fetchAudioItems()
            .sorted(byKeyPath: "createdAt", ascending: false)
        searchResults = results
        
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
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
            reloadPlayingRows()
            return
        }
        
        let predicateString = tokens
            .map { "title CONTAINS[c] '\($0)'" }
            .joined(separator: " AND ")
        
        let predicate = NSPredicate(format: predicateString)
        searchResults = results.filter(predicate)
        
        tableView.reloadData()
        reloadPlayingRows()
    }
    
    // MARK: - Playing Indicator
    
    private func isItemPlaying(_ item: DownloadItem) -> Bool {
        return PlayerCenter.shared.currentPlayingItemId == item.id
    }
    
    private func reloadPlayingRows() {
        guard tableView.window != nil else { return }
        
        for cell in tableView.visibleCells {
            guard
                let indexPath = tableView.indexPath(for: cell),
                let item = searchResults?[indexPath.row] ?? results?[indexPath.row],
                let playingCell = cell as? DownloadTableViewCell
            else { continue }
            
            let isCurrent = isItemPlaying(item)
            playingCell.setPlaying(isCurrent && PlayerCenter.shared.isActuallyPlaying)
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
    
    private func updateRowsFromNotification(note: Notification) -> Bool {
        let previousId = note.userInfo?["previousId"] as? String
        let currentId  = note.userInfo?["currentId"] as? String
        
        var didHandle = false
        
        // update old row (turn off)
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
    
    @objc private func appDidBecomeActive() {
        reloadPlayingRows()
    }
    
    @objc private func playerItemChanged(_ note: Notification) {
        if updateRowsFromNotification(note: note) {
            return
        }
        reloadPlayingRows()
    }
}

// MARK: - UITableViewDataSource

extension AudioController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: DownloadTableViewCell.identifier,
            for: indexPath
        ) as! DownloadTableViewCell
        
        let item = searchResults[indexPath.row]
        cell.configure(with: item, mode: .audio)
        cell.delegate = self
        
        let isCurrent = isItemPlaying(item)
        cell.setPlaying(isCurrent && PlayerCenter.shared.isActuallyPlaying)
        
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
        reloadPlayingRows()
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

//MARK: - MiniPlayerAdjustable Delegate

extension AudioController: MiniPlayerAdjustable {
    func setMiniPlayerVisible(_ visible: Bool, height: CGFloat) {
        var inset = tableView.contentInset
        inset.bottom = visible ? height : 0
        tableView.contentInset = inset
        tableView.scrollIndicatorInsets = inset
    }
}
