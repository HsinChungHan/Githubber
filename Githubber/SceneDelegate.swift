//
//  SceneDelegate.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/16.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let remoteUsersRepo = RemoteUserRepository()
        let localUsersStore = StoreUsersRepository()
        let usersRepoStore = StoreUsersReposRepository()
        let useCase = GetUsersUseCase.init(remoteRepo: remoteUsersRepo, usersStore: localUsersStore, reposStore: usersRepoStore)
        let viewModel = UserListViewModel(useCase: useCase)
        let rootViewController = UserListViewController(viewModel: viewModel, remoteRepo: remoteUsersRepo)
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: rootViewController)
        self.window = window
        window.makeKeyAndVisible()
        
    }
}

