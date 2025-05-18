//
//  StoreUsersRepository.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation
import RHCacheStoreAPI   // exposes RHActorCacheStoreAPIProtocol

/*
   This repository caches the paginated response of the
   GitHub REST v3 endpoint:
 
       GET /users         (https://api.github.com/users)
 
   • The endpoint returns *public* accounts (user + org) sorted by sign-up date.
   • Pagination is cursor-based:   ?since=<lastID>&per_page=<N>
   • Each page is stored under the key pattern:   users_since_<cursor>.
   • A separate key `users_last_fetch_time` records when data was last fetched,
     so callers can decide when the cache is stale.
 */

enum StoreUsersRepositoryError: Error {
    // last-fetch timestamp
    case failedSaveLastFetchTime
    case failedGetLastFetchTime
    
    // users pages
    case failedSaveUsersPage
    case failedGetUsersPage
    case usersPageNotFound
}

// MARK: - Protocol

protocol StoreUsersRepositoryProtocol {
    // timestamp helpers
    func saveLastFetchTime(_ ts: TimeInterval) async throws
    func getLastFetchTime() async throws -> TimeInterval
    
    // cursor-based users pages
    func saveUsersPage(cursor: Int, page: PublicUsersPage) async throws
    func getUsersPage(cursor: Int) async throws -> PublicUsersPage
    
    // User avatar
    func saveUserAvatar(url: String, data: Data) async throws
    func updateUserAvatar(url: String, data: Data) async throws
    func getUserAvatar(url: String) async throws -> Data?
    
    // User detail
    func saveUserDetail(username: String, dto: GitHubUserDTO) async throws
    func getUserDetail(username: String) async throws -> GitHubUserDTO?
}

// MARK: - Repository

final class StoreUsersRepository: StoreUsersRepositoryProtocol {
    
    // MARK: Keys
    private func usersKey(for cursor: Int) -> String { "users_since_\(cursor)" }
    private let lastFetchTimeKey = "users_last_fetch_time"
    
    // MARK: Dependencies
    private let store: RHActorCacheStoreAPIProtocol
    
    /// Designated initializer
    /// - Parameter store: Optional external cache store.
    ///   * If provided, the repository uses it directly.
    ///   * If `nil`, the repository creates its own actor–codable store under the system temporary directory.
    init(store external: RHActorCacheStoreAPIProtocol? = nil) {
        if let ext = external {
            // Use the injected store
            self.store = ext
        } else {
            // Build a default store pointing to a temp file
            let cacheFactory = RHCacheStoreAPIImplementationFactory()
            let fileURL = FileManager.default
                .temporaryDirectory
                .appendingPathComponent("users_cache.txt")
            
            self.store = cacheFactory.makeActorCodableStore(with: fileURL)
        }
    }
    
    // MARK: - Last-Fetch Timestamp
    
    func saveLastFetchTime(_ ts: TimeInterval) async throws {
        do {
            try await store.insert(with: lastFetchTimeKey, json: "\(ts)")
        } catch {
            throw StoreUsersRepositoryError.failedSaveLastFetchTime
        }
    }
    
    func getLastFetchTime() async throws -> TimeInterval {
        let result = await store.retrieve(with: lastFetchTimeKey)
        switch result {
        case .empty:
            return TimeInterval.leastNormalMagnitude   // force refresh
        case let .found(json):
            guard
                let str = json as? String,
                let ts  = Double(str)
            else {
                throw StoreUsersRepositoryError.failedGetLastFetchTime
            }
            return ts
        case .failure:
            throw StoreUsersRepositoryError.failedGetLastFetchTime
        }
    }
    
    // MARK: - Users Pages (cursor)
    
    func saveUsersPage(cursor: Int, page: PublicUsersPage) async throws {
        do {
            let container = UsersPageContainer(users: page.users, nextSince: page.nextSince)
            let data      = try JSONEncoder().encode(container)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw StoreUsersRepositoryError.failedSaveUsersPage
            }
            try await store.insert(with: usersKey(for: cursor), json: jsonString)
        } catch {
            throw StoreUsersRepositoryError.failedSaveUsersPage
        }
    }
    
    func getUsersPage(cursor: Int) async throws -> PublicUsersPage {
        let result = await store.retrieve(with: usersKey(for: cursor))
        switch result {
        case .empty:
            throw StoreUsersRepositoryError.usersPageNotFound
        case let .found(json):
            return try await parseUsersPage(from: json)
        case .failure:
            throw StoreUsersRepositoryError.failedGetUsersPage
        }
    }
}

// MARK: - Private Helpers

private extension StoreUsersRepository {
    /// Decode cached JSON into PublicUsersPage
    func parseUsersPage(from json: Any) async throws -> PublicUsersPage {
        let data: Data
        
        if let jsonString = json as? String {
            guard let d = jsonString.data(using: .utf8) else {
                throw StoreUsersRepositoryError.failedGetUsersPage
            }
            data = d
        } else if let dict = json as? [String: Any] {
            data = try JSONSerialization.data(withJSONObject: dict)
        } else {
            throw StoreUsersRepositoryError.failedGetUsersPage
        }
        
        let container = try JSONDecoder().decode(UsersPageContainer.self, from: data)
        return PublicUsersPage(users: container.users, nextSince: container.nextSince)
    }
}

// MARK: - Store avatr
extension StoreUsersRepository {

    private func avatarKey(for url: String) -> String {
        "avatar_\(url)"
    }

    func saveUserAvatar(url: String, data: Data) async throws {
        let b64 = data.base64EncodedString()
        do {
            try await store.insert(with: avatarKey(for: url), json: b64)
        } catch {
            throw StoreUsersRepositoryError.failedSaveUsersPage
        }
    }

    func updateUserAvatar(url: String, data: Data) async throws {
        try await saveUserAvatar(url: url, data: data)
    }

    func getUserAvatar(url: String) async throws -> Data? {
        let result = await store.retrieve(with: avatarKey(for: url))
        switch result {
        case .empty:
            return nil
        case let .found(json):
            guard let b64 = json as? String,
                  let data = Data(base64Encoded: b64)
            else {
                return nil
            }
            return data
        case .failure:
            return nil
        }
    }
}

// MARK: - User detail
extension StoreUsersRepository {
    private func detailKey(for username: String) -> String {
        "user_detail_\(username)"
    }

    func saveUserDetail(username: String, dto: GitHubUserDTO) async throws {
        let data = try JSONEncoder().encode(dto)
        let json = data.base64EncodedString()
        try await store.insert(with: detailKey(for: username), json: json)
    }

    func getUserDetail(username: String) async throws -> GitHubUserDTO? {
        let result = await store.retrieve(with: detailKey(for: username))
        switch result {
        case .found(let json):
            if let b64 = json as? String,
               let data = Data(base64Encoded: b64) {
                return try JSONDecoder().decode(GitHubUserDTO.self, from: data)
            }
            return nil
        case .empty, .failure:
            return nil
        }
    }
}
