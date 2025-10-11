//
//  SceneDelegate.swift
//  ListenUp
//
//  Created by S M H  on 04/06/2025.
//

import UIKit
import AVFoundation
import WebKit
import MediaPlayer


class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        
        guard let scene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: scene)
        window?.rootViewController = MainTabBarController()
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        setupMiniPlayerIfNeeded()
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        
    }

    func setupMiniPlayerIfNeeded() {
        // Check if there's an active player session
        if PlayerCenter.shared.player.currentItem != nil {
            if let tabBarController = window?.rootViewController as? UITabBarController {
                MiniPlayerContainerViewController.shared.show(in: tabBarController)
            }
        }
    }

}

