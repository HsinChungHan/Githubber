//
//  GetUsersUseCaseTests.swift
//  GithubberTests
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import XCTest
@testable import Githubber
@testable import RHCacheStoreAPI
@testable import RHCacheStore

// MARK: - Mock RemoteUserRepository
final class MockRemoteUserRepo: RemoteUserRepositoryProtocol {

    // Stubbed responses
    var publicUsersResult: Result<PublicUsersPage, RemoteUserRepositoryError> = .failure(.listUsers)
    var reposResult: Result<UserReposPage, RemoteUserRepositoryError>        = .failure(.listRepos)

    func fetchPublicUsers(since: Int, perPage: Int) async -> Result<PublicUsersPage, RemoteUserRepositoryError> {
        return publicUsersResult
    }

    func fetchUser(username: String) async -> Result<GitHubUserDTO, RemoteUserRepositoryError> {
        .failure(.getUser)
    }

    func fetchUserRepos(username: String, page: Int, perPage: Int) async -> Result<UserReposPage, RemoteUserRepositoryError> {
        return reposResult
    }

    func searchUsers(query: String, page: Int, perPage: Int) async -> Result<SearchUsersPage, RemoteUserRepositoryError> {
        .failure(.searchUsers)
    }
}

// MARK: - In-memory Stores

actor MockUsersStore: StoreUsersRepositoryProtocol {
    var lastFetch: TimeInterval = TimeInterval.leastNormalMagnitude
    var pages: [Int: PublicUsersPage] = [:]

    // Users
    func saveUsersPage(cursor: Int, page: PublicUsersPage) async throws { pages[cursor] = page }
    func getUsersPage(cursor: Int) async throws -> PublicUsersPage {
        guard let p = pages[cursor] else { throw StoreUsersRepositoryError.usersPageNotFound }
        return p
    }

    // Timestamps
    func saveLastFetchTime(_ ts: TimeInterval) async throws { lastFetch = ts }
    func getLastFetchTime() async throws -> TimeInterval { lastFetch }
}

actor MockReposStore: StoreUsersReposRepositoryProtocol {
    var lastFetch: [String: TimeInterval] = [:]
    var pages: [String: [Int: UserReposPage]] = [:]

    // Repos
    func saveReposPage(username: String, page: Int, pageData: UserReposPage) async throws {
        var dict = pages[username] ?? [:]
        dict[page] = pageData
        pages[username] = dict
    }

    func getReposPage(username: String, page: Int) async throws -> UserReposPage {
        guard let p = pages[username]?[page] else {
            throw StoreUsersReposRepositoryError.reposPageNotFound
        }
        return p
    }

    // Timestamps
    func saveLastFetchTime(username: String, ts: TimeInterval) async throws {
        lastFetch[username] = ts
    }
    func getLastFetchTime(username: String) async throws -> TimeInterval {
        lastFetch[username] ?? TimeInterval.leastNormalMagnitude
    }
}

// MARK: - Tests

final class GetUsersUseCaseTests: XCTestCase {

    private var useCase: GetUsersUseCase!
    private var mockRemote: MockRemoteUserRepo!
    private var userStore: MockUsersStore!
    private var repoStore: MockReposStore!

    override func setUp() async throws {
        mockRemote = MockRemoteUserRepo()
        userStore  = MockUsersStore()
        repoStore  = MockReposStore()
        useCase    = GetUsersUseCase(remoteRepo: mockRemote,
                                     usersStore: userStore,
                                     reposStore: repoStore)
    }

    override func tearDown() async throws {
        useCase    = nil
        mockRemote = nil
        userStore  = nil
        repoStore  = nil
    }

    // MARK: - Public users

    /// Should return local cache when still fresh
    func test_getUsers_usesLocalCache_whenFresh() async throws {
        // Prepare local cache with DTO
        let dto = SearchUserDTO(login: "octocat", id: 1, avatarUrl: URL(string: "https://")!)
        let cachedDTOPage = PublicUsersPage(users: [dto], nextSince: 135)
        try await userStore.saveUsersPage(cursor: 0, page: cachedDTOPage)
        try await userStore.saveLastFetchTime(Date().timeIntervalSince1970)

        // Call domain-facing API
        let page = try await useCase.getUsers(cursor: 0,
                                              perPage: 30,
                                              freshnessMinutes: 30)

        // Domain model has mapped username
        XCTAssertEqual(page.users.first?.username, "octocat")
        XCTAssertEqual(page.nextSince, 135)
    }

    /// Should hit remote and update cache when stale
    func test_getUsers_fetchRemote_whenStale() async throws {
        // Local outdated timestamp
        try await userStore.saveLastFetchTime(Date().timeIntervalSince1970 - 4000)

        // Remote returns new DTO page
        let dto = SearchUserDTO(login: "newuser", id: 9, avatarUrl: URL(string: "https://")!)
        let remoteDTOPage = PublicUsersPage(users: [dto], nextSince: 200)
        mockRemote.publicUsersResult = .success(remoteDTOPage)

        let page = try await useCase.getUsers(cursor: 0,
                                              perPage: 30,
                                              freshnessMinutes: 30)

        // Assert returned domain page & cache updated
        XCTAssertEqual(page.users.first?.username, "newuser")
        XCTAssertEqual(page.nextSince, 200)

        let cachedDTO = try await userStore.getUsersPage(cursor: 0)
        XCTAssertEqual(cachedDTO.users.first?.login, "newuser")
    }

    // MARK: - User repos

    func test_getUserRepos_usesLocalCache_whenFresh() async throws {
        let dto = GitHubRepoDTO(name: "Sample", language: nil,
                               stargazersCount: 0, description: nil,
                               fork: false, htmlUrl: URL(string: "https://")!)
        let cachedDTOPage = UserReposPage(repos: [dto], nextPage: nil)
        try await repoStore.saveReposPage(username: "octocat", page: 1, pageData: cachedDTOPage)
        try await repoStore.saveLastFetchTime(username: "octocat",
                                              ts: Date().timeIntervalSince1970)

        let result = try await useCase.getUserRepos(username: "octocat",
                                                    page: 1,
                                                    perPage: 30,
                                                    freshnessMinutes: 30)

        // Domain Repo maps name
        XCTAssertEqual(result.repos.first?.name, "Sample")
        XCTAssertNil(result.nextPage)
    }

    func test_getUserRepos_fetchRemote_whenStale() async throws {
        try await repoStore.saveLastFetchTime(username: "octocat",
                                              ts: Date().timeIntervalSince1970 - 5000)

        let dto = GitHubRepoDTO(name: "Remote",
                                language: "Swift",
                                stargazersCount: 100,
                                description: nil,
                                fork: false,
                                htmlUrl: URL(string: "https://")!)
        let remoteDTOPage = UserReposPage(repos: [dto], nextPage: 2)
        mockRemote.reposResult = .success(remoteDTOPage)

        let result = try await useCase.getUserRepos(username: "octocat",
                                                    page: 1,
                                                    perPage: 30,
                                                    freshnessMinutes: 30)

        XCTAssertEqual(result.repos.first?.name, "Remote")
        XCTAssertEqual(result.nextPage, 2)

        let cachedDTO = try await repoStore.getReposPage(username: "octocat", page: 1)
        XCTAssertEqual(cachedDTO.repos.first?.name, "Remote")
    }

    // MARK: - Error handling

    func test_getUsers_remoteFailure_throwsError() async throws {
        mockRemote.publicUsersResult = .failure(.listUsers)

        do {
            _ = try await useCase.getUsers(cursor: 0,
                                           perPage: 30,
                                           freshnessMinutes: 0)
            XCTFail("Expected failedToGetPublicUsers error")
        } catch let err as GetUsersUseCaseError {
            XCTAssertEqual(err, .failedToGetPublicUsers)
        }
    }
}
