//
//  StoreUsersReposRepository.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation
import RHCacheStoreAPI   // exposes RHActorCacheStoreAPIProtocol

/*
   This repository caches the paginated repository list of a *single* GitHub user,
   i.e. the response of

       GET /users/{username}/repos

   • Pagination is page-based:  ?page=<page>&per_page=<N>
   • Each page is stored under the key pattern:
         repos_<username>_page_<page>
   • A per-user key  repos_<username>_last_fetch_time  records when repos were
     last fetched, so callers can decide when cache is stale.
 */

enum StoreUsersReposRepositoryError: Error {
    // last-fetch timestamp
    case failedSaveLastFetchTime
    case failedGetLastFetchTime

    // repo pages
    case failedSaveReposPage
    case failedGetReposPage
    case reposPageNotFound
}

// MARK: - Protocol

protocol StoreUsersReposRepositoryProtocol {
    // timestamp helpers (per user)
    func saveLastFetchTime(username: String, ts: TimeInterval) async throws
    func getLastFetchTime(username: String) async throws -> TimeInterval

    // page-based repo helpers
    func saveReposPage(username: String, page: Int, pageData: UserReposPage) async throws
    func getReposPage(username: String, page: Int) async throws -> UserReposPage
}

// MARK: - Repository

final class StoreUsersReposRepository: StoreUsersReposRepositoryProtocol {

    // MARK: Keys
    private func reposKey(username: String, page: Int) -> String {
        "repos_\(username)_page_\(page)"
    }
    private func lastFetchKey(username: String) -> String {
        "repos_\(username)_last_fetch_time"
    }

    // MARK: Dependencies
    private let store: RHActorCacheStoreAPIProtocol

    /// Designated initializer
    /// - Parameter store: Optional external cache store.
    ///   Uses external store if provided; otherwise creates a default actor-codable store.
    init(store external: RHActorCacheStoreAPIProtocol? = nil) {
        if let ext = external {
            self.store = ext
        } else {
            let factory = RHCacheStoreAPIImplementationFactory()
            let fileURL = FileManager.default
                .temporaryDirectory
                .appendingPathComponent("user_repos_cache.txt")
            self.store = factory.makeActorCodableStore(with: fileURL)
        }
    }

    // MARK: - Last-Fetch Timestamp (per user)

    func saveLastFetchTime(username: String, ts: TimeInterval) async throws {
        do {
            try await store.insert(with: lastFetchKey(username: username), json: "\(ts)")
        } catch {
            throw StoreUsersReposRepositoryError.failedSaveLastFetchTime
        }
    }

    func getLastFetchTime(username: String) async throws -> TimeInterval {
        let result = await store.retrieve(with: lastFetchKey(username: username))
        switch result {
        case .empty:
            return TimeInterval.leastNormalMagnitude      // force refresh
        case let .found(json):
            guard let str = json as? String, let ts = Double(str) else {
                throw StoreUsersReposRepositoryError.failedGetLastFetchTime
            }
            return ts
        case .failure:
            throw StoreUsersReposRepositoryError.failedGetLastFetchTime
        }
    }

    // MARK: - Repo Pages (page-based)

    func saveReposPage(username: String,
                       page: Int,
                       pageData: UserReposPage) async throws {
        do {
            let container = ReposPageContainer(repos: pageData.repos,
                                               nextPage: pageData.nextPage)
            let data = try JSONEncoder().encode(container)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw StoreUsersReposRepositoryError.failedSaveReposPage
            }
            try await store.insert(with: reposKey(username: username, page: page), json: jsonString)
        } catch {
            throw StoreUsersReposRepositoryError.failedSaveReposPage
        }
    }

    func getReposPage(username: String, page: Int) async throws -> UserReposPage {
        let result = await store.retrieve(with: reposKey(username: username, page: page))
        switch result {
        case .empty:
            throw StoreUsersReposRepositoryError.reposPageNotFound
        case let .found(json):
            return try await parseReposPage(from: json)
        case .failure:
            throw StoreUsersReposRepositoryError.failedGetReposPage
        }
    }
}

// MARK: - Private Helpers

private extension StoreUsersReposRepository {

    /// Codable wrapper that stores repo list plus the next page index
    struct ReposPageContainer: Codable {
        let repos: [GitHubRepoDTO]
        let nextPage: Int?
    }

    /// Decode cached JSON into `UserReposPage`
    func parseReposPage(from json: Any) async throws -> UserReposPage {
        let data: Data

        if let str = json as? String {
            guard let d = str.data(using: .utf8) else {
                throw StoreUsersReposRepositoryError.failedGetReposPage
            }
            data = d
        } else if let dict = json as? [String: Any] {
            data = try JSONSerialization.data(withJSONObject: dict)
        } else {
            throw StoreUsersReposRepositoryError.failedGetReposPage
        }

        let container = try JSONDecoder().decode(ReposPageContainer.self, from: data)
        return UserReposPage(repos: container.repos, nextPage: container.nextPage)
    }
}
