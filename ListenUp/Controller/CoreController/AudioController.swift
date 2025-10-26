//
//  AudioController.swift
//  ListenUp
//
//  Created by S M H  on 25/10/2025.
//

import UIKit
import RealmSwift


class AudioController: UIViewController {
    
    //MARK: - Properties
    private var results: Results<DownloadItem>!
    private var searchResults: Results<DownloadItem>!
    private var notificationToken: NotificationToken?
    
    lazy var sortButton = UIBarButtonItem(
        image: UIImage(systemName: "arrow.up.arrow.down"),
        style: .plain,
        target: self,
        action: #selector(sortButtonTapped))
    
    lazy var deleteButton = UIBarButtonItem(
        image: UIImage(systemName: "trash"),
        style: .done,
        target: self,
        action: #selector(deleteButtonTapped))
    
    lazy var selectAllButton = UIBarButtonItem(
        image: UIImage(systemName: "checkmark.circle"),
        style: .plain,
        target: self,
        action: #selector(selectAllTapped))
    
    lazy var cancelButton = UIBarButtonItem(
        image: UIImage(systemName: "xmark"),
        style: .done,
        target: self,
        action: #selector(cancelTapped))
    
    //MARK: - UI Component
    private(set) lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.separatorStyle = .singleLine
        tv.rowHeight = 64
        tv.register(DownloadTableViewCell.self,
                    forCellReuseIdentifier: DownloadTableViewCell.identifier)
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
    
    //MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()

        configureUI()
        fetchResult()
        observeRealmChanges()
    }
    
    //MARK: - HelperFunctions
    private func configureUI() {
        view.backgroundColor = Style.viewBackgroundColor
        
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
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
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    private func fetchResult() {
        results = RealmService.shared.fetchAudioItems().sorted(byKeyPath: "createdAt", ascending: false)
        searchResults = results
        tableView.reloadData()
    }
    
    private func observeRealmChanges() {
        notificationToken = searchResults.observe { [weak self] changes in
            guard let self = self else { return }
            switch changes {
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
                })
                
                if self.tableView.isEditing {
                    self.updateSelectAllButtonTitle()
                }
            default:
                break
            }
        }
    }
    
    deinit {
        notificationToken?.invalidate()
    }
    
    //MARK: - Helper Functions
    
    private func sortAudioFiles(by keyPath: String, ascending: Bool) {
        searchResults  = searchResults
            .sorted(byKeyPath: keyPath, ascending: ascending)
        
        tableView.reloadData()
    }
    
    //MARK: - Selector
    
    @objc private func refreshData() {
        fetchResult()
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
        
        tableView.refreshControl?.endRefreshing()
    }
    
    //MARK: - Action for navigationItems
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

//MARK: - UITableView Delegate
extension AudioController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            updateSelectAllButtonTitle()
            return  // Don't deselect or play
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
        guard !tableView.isEditing else {
            updateSelectAllButtonTitle()
            return
        }
        
        let item = searchResults[indexPath.row]
        guard item.status == .completed else { return }
        
        /// need to implement play audio
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard tableView.isEditing else { return }
        updateSelectAllButtonTitle()
    }
    
    
}

//MARK: - UITableView DataSource
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

extension AudioController: DownloadTableViewCellDelegate {
    func cell(_ cell: DownloadTableViewCell, didTapOptionFor item: DownloadItem) {
        showActionSheet(for: item)
    }
}


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
    
//    func willEnterSelectionMode() {
//        if currentlyPlayingItemId != nil {
//            stopPlaying()
//        }
//    }
    
    // Customize delete message for audio
    func customizeDeleteAlert(count: Int) -> (title: String, message: String) {
        let title = count == 1 ? "Delete 1 audio?" : "Delete \(count) audios?"
        return (title, "This will permanently remove them.")
    }
}

// MARK: - ActionSheetConfigurable
extension AudioController: ActionSheetConfigurable {
    /// action sheet for option button
    func configureActions(for item: DownloadItem) -> [UIAlertAction] {
        var actions: [UIAlertAction] = []
        
        // Share Action (simpler for audio)
        let shareAction = UIAlertAction(title: "Share", style: .default) { [weak self] _ in
            self?.shareAudio(item)
        }
        actions.append(shareAction)
        
        // Delete Action
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.showDeleteConfirmation(for: item)
        }
        actions.append(deleteAction)
        
        return actions
    }
    
    private func shareAudio(_ item: DownloadItem) {
        guard let localPath = item.localPath,
              let fileURL = FileHelper.fileURL(for: localPath) else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        present(activityVC, animated: true)
    }
    
    /// delete function for actionSheet
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
}
