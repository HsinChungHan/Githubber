//
//  SceneDelegate.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/16.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = (scene as? UIWindowScene) else { return }

        // 1. 建立 MainTabBarController
        let tabBar = MainTabBarController()

        // 2. 建立 window 並指定 tabBar 為 root
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = tabBar
        self.window = window
        window.makeKeyAndVisible()
    }
}
