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
    
    //MARK: - UI Component
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
    
    //MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureUI()
        fetchResult()
    }
    
    //MARK: - HelperFunctions
    private func configureUI() {
        view.backgroundColor = Style.viewBackgroundColor
        
        view.addSubview(tableView)
//        view.addSubview(emptyStateLabel)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
//            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelectionDuringEditing = true
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    private func fetchResult() {
        results = RealmService.shared.fetchAudioItems().sorted(byKeyPath: "createdAt", ascending: false)
        searchResults = results
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
    

}

//MARK: - UITableView Delegate
extension AudioController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("Debug: selected item : \(searchResults[indexPath.row])")
        tableView.deselectRow(at: indexPath, animated: true)
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
        print("Debug: didTapOptionFor : \(item)")
    }
}
