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
    private var token: NotificationToken?
    private var progressCache: [ObjectId: Float] = [:]
    
    // MARK: - UI Components
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.separatorStyle = .singleLine
        tv.rowHeight = 54
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
    
    
    //MARK: - LifeCycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        fetchResult()
//        deleteAll()
        configureToken()
    }
    
    deinit {
        token?.invalidate()
    }
    
    //MARK: - HelperFunctions
    
    private func setupUI() {
        title = "History"
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
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
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
    
    func fetchResult() {
        results = RealmService.shared.fetchAllMedia().sorted(byKeyPath: "createdAt", ascending: false)
        tableView.reloadData()
    }
    
    func deleteAll() {
        RealmService.shared.deleteAll()
    }
    
    func playVideo(at fileURL: URL, from presenter: UIViewController) {
        let player = AVPlayer(url: fileURL)
        let vc = AVPlayerViewController()
        vc.player = player
        presenter.present(vc, animated: true) { player.play() }
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
    
    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func getBaseURL(from relativePath: String) -> URL {
        documentsURL().appendingPathComponent(relativePath, isDirectory: false)
    }

    
    //MARK: - Selector
    
    @objc func refreshData() {
        tableView.refreshControl?.endRefreshing()
    }
    
    @objc private func onFinished(_ note: Notification) {
        guard let id = note.userInfo?["id"] as? ObjectId else { return }
        progressCache[id] = 1.0
    }
}

//MARK: - UITableViewDataSource
extension HistoryController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = results[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: HistoryTableViewCell.identifier, for: indexPath) as? HistoryTableViewCell else {
            return UITableViewCell()
        }
        
        cell.configure(with: item)
        // Progress: if we have a cached value use it; else 1.0 if file exists; else 0
//        let p = progressCache[item.id] ?? (item.localVideoPath != nil ? 1.0 : 0.0)
//        cell.setProgress(p)
        
//        cell.delegate = self
        
        return cell
    }
}

//MARK: - UITableViewDelegate
extension HistoryController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let item = results[indexPath.row]
        guard item.status == .completed, let path = item.localPath else { return }
        playVideo(at: getBaseURL(from: path), from: self)
    }
}

// MARK: - HistoryTableViewCellDelegate
extension HistoryController: HistoryTableViewCellDelegate {
    func didTapOptionButton(for cell: HistoryTableViewCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        showActionSheet(for: indexPath)
    }
}
