//
//  MainTabBarController.swift
//  ListenUp
//
//  Created by S M H  on 04/06/2025.
//

import UIKit

class MainTabBarController: UITabBarController {
    
    //MARK: - Properties
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTabController()
    }
    
    //MARK: - API
    
    
    //MARK: - HelperFunctions
    
    private func configureTabController() {
        
        let browserController = configureNavigationController(tabImage: UIImage(systemName: "globe")!, rootViewController: BrowserController(), title: "Browser")
        
//        let browserController = configureNavigationController(tabImage: UIImage(systemName: "magnifyingglass")!, rootViewController: CategoriesViewController(), title: "Search")
        
        let LibraryController = configureNavigationController(tabImage: UIImage(systemName: "star")!, rootViewController: LibraryController(), title: "Favourites")
        
        let HistoryController = configureNavigationController(tabImage: UIImage(systemName: "clock")!, rootViewController: HistoryController(), title: "History")
        
        let ProfileController = configureNavigationController(tabImage: UIImage(systemName: "gear")!, rootViewController: SettingsController(), title: "Setting")
        
        viewControllers = [browserController, LibraryController, HistoryController, ProfileController]
        
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.shadowColor = .clear
        appearance.shadowImage = nil
        
        tabBar.standardAppearance = appearance
        
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        
        tabBar.isTranslucent = false
        tabBar.tintColor = .blue
        tabBar.unselectedItemTintColor = .secondaryLabel
        
    }
    
    private func configureNavigationController(tabImage: UIImage, rootViewController: UIViewController, title: String? = nil) -> UINavigationController {
        
        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.tabBarItem.image = tabImage
        navigationController.tabBarItem.title = title
        navigationController.navigationBar.isTranslucent = false
        
        return navigationController
    }
    
}

