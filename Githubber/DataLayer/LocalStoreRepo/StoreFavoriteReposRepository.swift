//
//  StoreFavoriteReposRepository.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation
import RHCacheStoreAPI   // exposes RHActorCacheStoreAPIProtocol

// MARK: –– Codable container for a single favorite repo
private struct FavoriteRepoCodable: Codable {
    let name: String
    let language: String?
    let stars: Int
    let description: String?
    let url: URL

    init(from repo: Repo) {
        self.name        = repo.name
        self.language    = repo.language
        self.stars       = repo.stars
        self.description = repo.description
        self.url         = repo.url
    }

    func toDomain() -> Repo {
        return Repo(name: name,
                    language: language,
                    stars: stars,
                    description: description,
                    url: url)
    }
}

// MARK: –– Protocol

protocol StoreFavoriteReposRepositoryProtocol {
    func saveFavorite(_ repo: Repo) async throws
    func removeFavorite(_ repo: Repo) async throws
    func getFavorites() async throws -> [Repo]
}

// MARK: –– Implementation

final class StoreFavoriteReposRepository: StoreFavoriteReposRepositoryProtocol {

    private let store: RHActorCacheStoreAPIProtocol
    private let key = "favorite_repos"
    var fileURL: URL?

    init(store external: RHActorCacheStoreAPIProtocol? = nil) {
        if let ext = external {
            self.store = ext
        } else {
            let factory = RHCacheStoreAPIImplementationFactory()
            let fileURL = FileManager.default
                .temporaryDirectory
                .appendingPathComponent("favorites_cache.txt")
            print("Avatar cache file:", fileURL.path)
            self.fileURL = fileURL
            self.store = factory.makeActorCodableStore(with: fileURL)
        }
    }

    func saveFavorite(_ repo: Repo) async throws {
        var list = try await loadAllCodable()
        let codable = FavoriteRepoCodable(from: repo)
        if !list.contains(where: { $0.url == codable.url }) {
            list.append(codable)
        }
        print("Avatar cache file:", fileURL?.path)
        try await persist(list)
    }

    func removeFavorite(_ repo: Repo) async throws {
        var list = try await loadAllCodable()
        list.removeAll { $0.url == repo.url }
        try await persist(list)
    }

    func getFavorites() async throws -> [Repo] {
        let list = try await loadAllCodable()
        print("Avatar cache file:", fileURL?.path)
        return list.map { $0.toDomain() }
    }

    // MARK: - Helpers

    private func loadAllCodable() async throws -> [FavoriteRepoCodable] {
        let result = await store.retrieve(with: key)
        switch result {
        case .empty:
            return []
        case .found(let json):
            // JSON could be String or Dictionary
            let data: Data
            if let str = json as? String {
                guard let d = str.data(using: .utf8) else {
                    return []
                }
                data = d
            } else if let dict = json as? [String: Any] {
                data = try JSONSerialization.data(withJSONObject: dict)
            } else {
                return []
            }
            return try JSONDecoder().decode([FavoriteRepoCodable].self, from: data)
        case .failure:
            return []
        }
    }

    private func persist(_ list: [FavoriteRepoCodable]) async throws {
        let data = try JSONEncoder().encode(list)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        try await store.insert(with: key, json: jsonString)
    }
}

