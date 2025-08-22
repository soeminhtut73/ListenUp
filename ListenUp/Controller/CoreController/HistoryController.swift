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
    
    private var items: Results<MediaModel>!
    private var token: NotificationToken?
    private var progressCache: [ObjectId: Float] = [:]
    
    // MARK: - UI Components
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.separatorStyle = .singleLine
        tv.rowHeight = 54
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
    }
    
    deinit {
        token?.invalidate()
        NotificationCenter.default.removeObserver(self)
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
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(HistoryTableViewCell.self, forCellReuseIdentifier: HistoryTableViewCell.identifier)
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
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
    
    
    
    //MARK: - Selector
    
    @objc func refreshData() {
        tableView.refreshControl?.endRefreshing()
    }
    
    @objc private func onProgress(_ note: Notification) {
        guard let id = note.userInfo?["id"] as? ObjectId,
              let p  = note.userInfo?["progress"] as? Float else { return }
        if let row = items.firstIndex(where: { $0.id == id }) {
            DispatchQueue.main.async {
                if let cell = self.tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? HistoryTableViewCell {
                    cell.setProgress(p)
                }
            }
        }
    }
    
    @objc private func onFinished(_ note: Notification) {
        guard let id = note.userInfo?["id"] as? ObjectId else { return }
        progressCache[id] = 1.0
    }
}

//MARK: - UITableViewDataSource
extension HistoryController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = items[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: HistoryTableViewCell.identifier, for: indexPath) as? HistoryTableViewCell else {
            return UITableViewCell()
        }
        
        cell.item = item
        // Progress: if we have a cached value use it; else 1.0 if file exists; else 0
        let p = progressCache[item.id] ?? (item.localVideoPath != nil ? 1.0 : 0.0)
        cell.setProgress(p)
        
        cell.delegate = self
        
        return cell
    }
}

//MARK: - UITableViewDelegate
extension HistoryController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        if let path = item.localVideoPath {
            let url = URL(fileURLWithPath: path)
            playVideo(at: url, from: self)
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
