//
//  FavoriteReposUseCase.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation

// MARK: - Protocol
protocol FavoriteReposUseCaseProtocol {
    func addFavorite(_ repo: Repo) async throws
    func removeFavorite(_ repo: Repo) async throws
    func fetchFavorites() async throws -> [Repo]
}

// MARK: - Implementation
final class FavoriteReposUseCase: FavoriteReposUseCaseProtocol {
    private let store: StoreFavoriteReposRepositoryProtocol

    init(store: StoreFavoriteReposRepositoryProtocol) {
        self.store = store
    }

    func addFavorite(_ repo: Repo) async throws {
        try await store.saveFavorite(repo)
    }

    func removeFavorite(_ repo: Repo) async throws {
        try await store.removeFavorite(repo)
    }

    func fetchFavorites() async throws -> [Repo] {
        try await store.getFavorites()
    }
}
