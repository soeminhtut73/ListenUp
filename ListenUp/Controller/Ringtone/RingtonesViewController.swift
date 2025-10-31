//
//  RingtonesViewController.swift
//  ListenUp
//
//  Created by S M H  on 16/10/2025.
//

import UIKit

class RingtonesViewController: UIViewController {
    private let tableView = UITableView()
    private var ringtones: [Ringtone] = []
    private let category: MusicCategory
    
    init(category: MusicCategory) {
        self.category = category
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = category.name
        setupTableView()
        fetchRingtones()
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(RingtoneCell.self, forCellReuseIdentifier: "RingtoneCell")
    }
    
    private func fetchRingtones() {
        Task {
            do {
                let paginatedData = try await APIService.shared.fetchRingtones(categoryId: category.id)
                ringtones = paginatedData.data
                tableView.reloadData()
            } catch {
                print("Error: \(error)")
            }
        }
    }
}

extension RingtonesViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ringtones.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RingtoneCell", for: indexPath) as! RingtoneCell
        cell.configure(with: ringtones[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let ringtone = ringtones[indexPath.row]
        let detailVC = RingtoneDetailViewController(ringtone: ringtone)
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}
