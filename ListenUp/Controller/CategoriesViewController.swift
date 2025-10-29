//
//  CategoriesViewController.swift
//  ListenUp
//
//  Created by S M H  on 16/10/2025.
//

import UIKit
import PhotosUI

class CategoriesViewController: UIViewController {
    
    private let tableView = UITableView()
    private var categories: [MusicCategory] = []
    
    private let kMaxDuration: TimeInterval = 20 * 60
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Categories"
        setupTableView()
        fetchCategories()
        setupNavigationMenu()
    }
    
    //MARK: - UISetup
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
        
        tableView.rowHeight = 54
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CategoryCell")
    }
    
    private func fetchCategories() {
        Task {
            do {
                categories = try await APIService.shared.fetchCategories()
                tableView.reloadData()
            } catch {
                showMessage(withTitle: "Error!", message: error.localizedDescription)
            }
        }
    }
    
    //MARK: - Setup Navigation
    private func setupNavigationMenu() {
        // Define actions
        let browseAction = UIAction(title: "Browse", image: UIImage(systemName: "globe")) { _ in
            self.openBrowserController()
        }
        
        // Combine into menu
        let menu = UIMenu(title: "", children: [browseAction])
        
        // Create bar button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            menu: menu
        )
    }
    
    private func openBrowserController() {
        let vc = BrowserController()
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension CategoriesViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath)
        let category = categories[indexPath.row]
        
        cell.textLabel?.text = category.name
        cell.detailTextLabel?.text = "\(category.ringtonesCount) ringtones"
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let category = categories[indexPath.row]
        let ringtonesVC = RingtonesViewController(category: category)
        navigationController?.pushViewController(ringtonesVC, animated: true)
    }
}
