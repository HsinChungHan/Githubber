//
//  MainTabBarController.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import UIKit

final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
    }

    private func setupTabs() {
        // Shared dependencies
        let remoteRepo  = RemoteUserRepository()
        let usersStore  = StoreUsersRepository()
        let reposStore  = StoreUsersReposRepository()
        let getUsersUseCase = GetUsersUseCase(
            remoteRepo: remoteRepo,
            usersStore: usersStore,
            reposStore: reposStore
        )
        let favoriteStore   = StoreFavoriteReposRepository()
        let favoriteUseCase = FavoriteReposUseCase(store: favoriteStore)

        // Tab 1: Users List
        let userListVM = UserListViewModel(useCase: getUsersUseCase, favoriteUseCase: favoriteUseCase)
        let userListVC = UserListViewController(
            viewModel: userListVM,
            remoteRepo: remoteRepo
        )
        userListVC.tabBarItem = UITabBarItem(
            title: "Users",
            image: UIImage(systemName: "person.3"),
            tag: 0
        )
        let nav1 = UINavigationController(rootViewController: userListVC)

        // Tab 2: Favorites
        let favoritesVM     = FavoriteReposViewModel(useCase: favoriteUseCase)
        let favoritesVC     = FavoriteReposViewController(viewModel: favoritesVM)
        favoritesVC.tabBarItem = UITabBarItem(
            title: "Favorites",
            image: UIImage(systemName: "star.fill"),
            tag: 1
        )
        let nav2 = UINavigationController(rootViewController: favoritesVC)

        viewControllers = [nav1, nav2]
    }
}

