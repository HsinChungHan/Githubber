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
        let tabBar = MainTabBarController()
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = tabBar
        self.window = window
        window.makeKeyAndVisible()
    }
}
