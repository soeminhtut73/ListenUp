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
        
        let browserController = configureNavigationController(tabImage: UIImage(systemName: "globe")!, rootViewController: BrowserController())
        
        let LibraryController = configureNavigationController(tabImage: UIImage(systemName: "star")!, rootViewController: LibraryController())
        
        let HistoryController = configureNavigationController(tabImage: UIImage(systemName: "clock")!, rootViewController: HistoryController())
        
        let ProfileController = configureNavigationController(tabImage: UIImage(systemName: "person")!, rootViewController: ProfileController())
        
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
    
    private func configureNavigationController(tabImage: UIImage, rootViewController: UIViewController) -> UINavigationController {
        
        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.tabBarItem.image = tabImage
        navigationController.navigationBar.isTranslucent = false
        
        return navigationController
    }
    
    
    //MARK: - Selector
    
}
