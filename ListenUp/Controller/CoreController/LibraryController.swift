//
//  LibraryController.swift
//  ListenUp
//
//  Created by S M H  on 04/06/2025.
//

import UIKit

private let reuseIdentifier = "LibraryTableViewCell"

class LibraryController: UITableViewController {
    
    //MARK: - Properties
    
    
    //MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureUI()
    }
    
    //MARK: - HelperFunctions
    private func configureUI() {
        view.backgroundColor = Style.viewBackgroundColor
        title = "Favourites"
        
        tableView.register(LibraryTableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.rowHeight = 54
    }
    
    //MARK: - Selector
    

}

//MARK: - UITableView Delegate
extension LibraryController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! LibraryTableViewCell
        
        return cell
    }
}

//MARK: - UITableView DataSource
extension LibraryController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("Debug: row selected : \(indexPath.row)")
    }
}
