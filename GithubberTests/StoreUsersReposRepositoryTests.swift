//
//  StoreUsersReposRepositoryTests.swift
//  GithubberTests
//
//  Created by Chung Han Hsin on 2025/5/18.
//


import XCTest
@testable import Githubber
@testable import RHCacheStoreAPI
@testable import RHCacheStore

// MARK: - Mock Store (in-memory, no real file I/O)

actor UsersReposMockStore: RHActorCacheStoreAPIProtocol {
    private var storage: [String: Any] = [:]
    
    func insert(with key: String, json: Any) async throws { storage[key] = json }
    
    func retrieve(with key: String) async -> RetriveCacheResult {
        storage[key].map { .found($0) } ?? .empty
    }
    
    func delete(with id: String) async throws {}
    func saveCache() async throws {}
    func loadCache() async throws {}
}

// MARK: - Tests

final class StoreUsersReposRepositoryTests: XCTestCase {
    
    private var repo: StoreUsersReposRepository!
    private var mockStore: UsersReposMockStore!
    
    override func setUp() async throws {
        mockStore = UsersReposMockStore()
        repo = StoreUsersReposRepository(store: mockStore)
    }
    
    override func tearDown() async throws {
        repo  = nil
        mockStore = nil
    }
    
    // MARK: - Last-fetch timestamp
    
    /// saveLastFetchTime / getLastFetchTime round-trip
    func test_saveAndGetLastFetchTime_success() async throws {
        let ts: TimeInterval = 1_708_000_123
        try await repo.saveLastFetchTime(username: "octocat", ts: ts)
        
        let fetched = try await repo.getLastFetchTime(username: "octocat")
        XCTAssertEqual(fetched, ts)
    }
    
    /// When no timestamp exists, should return minimal value
    func test_getLastFetchTime_empty_returnsMin() async throws {
        let fetched = try await repo.getLastFetchTime(username: "ghost")
        XCTAssertEqual(fetched, TimeInterval.leastNormalMagnitude)
    }
    
    // MARK: - Repo page caching
    
    /// saveReposPage / getReposPage round-trip
    func test_saveAndGetReposPage_success() async throws {
        // Build sample repo DTO
        let sampleRepo = Githubber.GitHubRepoDTO(
            name: "Hello-World",
            language: "Swift",
            stargazersCount: 42,
            description: "Sample repo",
            fork: false,
            htmlUrl: URL(string: "https://github.com/octocat/Hello-World")!
        )
        let pageData = Githubber.UserReposPage(repos: [sampleRepo], nextPage: 2)
        
        try await repo.saveReposPage(username: "octocat", page: 1, pageData: pageData)
        
        let cached = try await repo.getReposPage(username: "octocat", page: 1)
        
        XCTAssertEqual(cached.repos.first?.name, "Hello-World")
        XCTAssertEqual(cached.nextPage, 2)
    }
    
    /// getReposPage should throw when page not cached
    func test_getReposPage_empty_throwsNotFound() async throws {
        do {
            _ = try await repo.getReposPage(username: "octocat", page: 5)
            XCTFail("Expected reposPageNotFound error")
        } catch let err as StoreUsersReposRepositoryError {
            XCTAssertEqual(err, .reposPageNotFound)
        }
    }
}
