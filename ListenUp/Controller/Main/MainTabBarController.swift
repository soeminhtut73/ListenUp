//
//  MainTabBarController.swift
//  ListenUp
//
//  Created by S M H  on 04/06/2025.
//

import UIKit

class MainTabBarController: UITabBarController {
    
    //MARK: - Properties
    
    private var hasPreloadedTabs = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTabController()
        checkDidRegisterDeivceId()
    }
    
    //MARK: - HelperFunctions
    
    private func configureTabController() {
        
        let browserController = configureNavigationController(tabImage: UIImage(systemName: "magnifyingglass")!, rootViewController: CategoriesViewController(), title: "Search")
        
        let LibraryController = configureNavigationController(tabImage: UIImage(systemName: "music.note.house")!, rootViewController: AudioController(), title: "Tone")
        
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
    
    private func checkDidRegisterDeivceId() {
        guard !DeviceID.shared.exists() else { return }
        
        Task { @MainActor in
            do {
                let deviceId = DeviceID.shared.get()
                try await APIService.shared.registerDevice(deviceId: deviceId)
            } catch {
                self.showMessage(withTitle: "Oops!", message: "Failed to register device.")
            }
        }
    }
    
}

