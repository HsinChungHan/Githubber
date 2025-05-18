//
//  StoreUsersRepositoryTests.swift
//  GithubberTests
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import XCTest
@testable import Githubber
@testable import RHCacheStoreAPI
@testable import RHCacheStore

// MARK: - Mock Store
actor MockStore: RHActorCacheStoreAPIProtocol {
    private var storage: [String: Any] = [:]

    func insert(with key: String, json: Any) async throws {
        storage[key] = json
    }

    func retrieve(with key: String) async -> RetriveCacheResult {
        if let value = storage[key] { return .found(value) }
        return .empty
    }

    func delete(with id: String) async throws {}
    func saveCache() async throws {}
    func loadCache() async throws {}
}

// MARK: - Tests

final class StoreUsersRepositoryTests: XCTestCase {

    private var repository: StoreUsersRepository!
    private var mockStore: MockStore!

    override func setUp() async throws {
        mockStore   = MockStore()
        repository  = StoreUsersRepository(store: mockStore)
    }

    override func tearDown() async throws {
        repository = nil
        mockStore  = nil
    }

    // MARK: - Last fetch time

    /// saveLastFetchTime / getLastFetchTime round-trip
    func test_saveAndGetLastFetchTime_success() async throws {
        let ts: TimeInterval = 1_708_000_000   // example timestamp
        try await repository.saveLastFetchTime(ts)

        let fetched = try await repository.getLastFetchTime()
        XCTAssertEqual(fetched, ts, "Timestamp should round-trip without mutation")
    }

    /// getLastFetchTime when no data returns minimal value
    func test_getLastFetchTime_empty_returnsMin() async throws {
        let fetched = try await repository.getLastFetchTime()
        XCTAssertEqual(fetched, TimeInterval.leastNormalMagnitude,
                       "Should return min value when cache is empty")
    }

    // MARK: - Users page

    /// saveUsersPage / getUsersPage round-trip
    func test_saveAndGetUsersPage_success() async throws {
        // Build sample DTOs
        let user = SearchUserDTO(login: "octocat", id: 1, avatarUrl: URL(string:"https://img")!)
        let page = PublicUsersPage(users: [user], nextSince: 135)

        // Save page for cursor 0
        try await repository.saveUsersPage(cursor: 0, page: page)

        // Retrieve page
        let cached = try await repository.getUsersPage(cursor: 0)

        // Assertions
        XCTAssertEqual(cached.users.first?.id, 1)
        XCTAssertEqual(cached.nextSince, 135)
    }

    /// getUsersPage should throw when cache is missing
    func test_getUsersPage_empty_throwsNotFound() async throws {
        do {
            _ = try await repository.getUsersPage(cursor: 0)
            XCTFail("Expected usersPageNotFound error")
        } catch let err as StoreUsersRepositoryError {
            XCTAssertEqual(err, .usersPageNotFound)
        }
    }
}
