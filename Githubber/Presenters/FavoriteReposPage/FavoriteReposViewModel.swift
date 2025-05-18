//
//  FavoriteReposViewModel.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation

final class FavoriteReposViewModel {

    // MARK: - Dependencies
    private let useCase: FavoriteReposUseCaseProtocol

    // MARK: - Data
    private(set) var favorites: [Repo] = []

    // MARK: - Callbacks
    var onUpdate: (() -> Void)?
    var onError: ((Error) -> Void)?

    init(useCase: FavoriteReposUseCaseProtocol) {
        self.useCase = useCase
    }

    func loadFavorites() {
        Task {
            do {
                let list = try await useCase.fetchFavorites()
                DispatchQueue.main.async {
                    self.favorites = list
                    self.onUpdate?()
                }
            } catch {
                DispatchQueue.main.async {
                    self.onError?(error)
                }
            }
        }
    }

    func unfavorite(_ repo: Repo) {
        Task {
            do {
                if favorites.contains(where: { $0.url == repo.url }) {
                    try await useCase.removeFavorite(repo)
                } else {
                    try await useCase.addFavorite(repo)
                }
                // reload
                let list = try await useCase.fetchFavorites()
                DispatchQueue.main.async {
                    self.favorites = list
                    self.onUpdate?()
                }
            } catch {
                DispatchQueue.main.async {
                    self.onError?(error)
                }
            }
        }
    }
}

