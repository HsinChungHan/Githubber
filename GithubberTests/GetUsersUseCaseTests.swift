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
    var userDetailResult: Result<GitHubUserDTO, RemoteUserRepositoryError>  = .failure(.getUser)

    func fetchPublicUsers(since: Int, perPage: Int) async -> Result<PublicUsersPage, RemoteUserRepositoryError> {
        return publicUsersResult
    }

    func fetchUser(username: String) async -> Result<GitHubUserDTO, RemoteUserRepositoryError> {
        return userDetailResult
    }

    func fetchUserRepos(username: String, page: Int, perPage: Int) async -> Result<UserReposPage, RemoteUserRepositoryError> {
        return reposResult
    }

    func searchUsers(query: String, page: Int, perPage: Int) async -> Result<SearchUsersPage, RemoteUserRepositoryError> {
        return .failure(.searchUsers)
    }
}

// MARK: - In-memory Stores

actor MockUsersStore: StoreUsersRepositoryProtocol {
    // Avatar cache stubs
    func saveUserAvatar(url: String, data: Data) async throws {}
    func updateUserAvatar(url: String, data: Data) async throws {}
    func getUserAvatar(url: String) async throws -> Data? { nil }

    // User detail cache
    private var detailLastFetch: [String: TimeInterval] = [:]
    private var cachedDetails: [String: GitHubUserDTO] = [:]
    func saveUserDetail(username: String, dto: GitHubUserDTO) async throws {
        cachedDetails[username] = dto
    }
    func getUserDetail(username: String) async throws -> GitHubUserDTO? {
        return cachedDetails[username]
    }
    func saveLastDetailFetchTime(username: String, ts: TimeInterval) async throws {
        detailLastFetch[username] = ts
    }
    func getLastDetailFetchTime(username: String) async throws -> TimeInterval {
        return detailLastFetch[username] ?? .leastNormalMagnitude
    }

    // Public users cache
    var lastFetch: TimeInterval = .leastNormalMagnitude
    var pages: [Int: PublicUsersPage] = [:]
    func saveUsersPage(cursor: Int, page: PublicUsersPage) async throws {
        pages[cursor] = page
    }
    func getUsersPage(cursor: Int) async throws -> PublicUsersPage {
        guard let p = pages[cursor] else {
            throw StoreUsersRepositoryError.usersPageNotFound
        }
        return p
    }
    func saveLastFetchTime(_ ts: TimeInterval) async throws {
        lastFetch = ts
    }
    func getLastFetchTime() async throws -> TimeInterval {
        lastFetch
    }
}

actor MockReposStore: StoreUsersReposRepositoryProtocol {
    var lastFetch: [String: TimeInterval] = [:]
    var pages: [String: [Int: UserReposPage]] = [:]

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
    func saveLastFetchTime(username: String, ts: TimeInterval) async throws {
        lastFetch[username] = ts
    }
    func getLastFetchTime(username: String) async throws -> TimeInterval {
        lastFetch[username] ?? .leastNormalMagnitude
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
        useCase    = GetUsersUseCase(
            remoteRepo: mockRemote,
            usersStore: userStore,
            reposStore: repoStore
        )
    }

    override func tearDown() async throws {
        useCase    = nil
        mockRemote = nil
        userStore  = nil
        repoStore  = nil
    }

    // MARK: - Public users

    func test_getUsers_usesLocalCache_whenFresh() async throws {
        let dto = SearchUserDTO(
            login: "octocat",
            id: 1,
            avatarUrl: URL(string: "https://")!
        )
        let cachedDTOPage = PublicUsersPage(users: [dto], nextSince: 135)
        try await userStore.saveUsersPage(cursor: 0, page: cachedDTOPage)
        try await userStore.saveLastFetchTime(Date().timeIntervalSince1970)

        let page = try await useCase.getUsers(
            cursor: 0,
            perPage: 30,
            freshnessMinutes: 30
        )

        XCTAssertEqual(page.users.first?.username, "octocat")
        XCTAssertEqual(page.nextSince, 135)
    }

    func test_getUsers_fetchRemote_whenStale() async throws {
        try await userStore.saveLastFetchTime(Date().timeIntervalSince1970 - 4000)

        let dto = SearchUserDTO(
            login: "newuser",
            id: 9,
            avatarUrl: URL(string: "https://")!
        )
        let remoteDTOPage = PublicUsersPage(users: [dto], nextSince: 200)
        mockRemote.publicUsersResult = .success(remoteDTOPage)

        let page = try await useCase.getUsers(
            cursor: 0,
            perPage: 30,
            freshnessMinutes: 30
        )

        XCTAssertEqual(page.users.first?.username, "newuser")
        XCTAssertEqual(page.nextSince, 200)

        let cachedDTO = try await userStore.getUsersPage(cursor: 0)
        XCTAssertEqual(cachedDTO.users.first?.login, "newuser")
    }

    func test_getUsers_remoteFailure_throwsError() async throws {
        mockRemote.publicUsersResult = .failure(.listUsers)

        do {
            _ = try await useCase.getUsers(
                cursor: 0,
                perPage: 30,
                freshnessMinutes: 0
            )
            XCTFail("Expected failedToGetPublicUsers error")
        } catch let err as GetUsersUseCaseError {
            XCTAssertEqual(err, .failedToGetPublicUsers)
        }
    }

    // MARK: - User repos

    func test_getUserRepos_usesLocalCache_whenFresh() async throws {
        let dto = GitHubRepoDTO(
            name: "Sample",
            language: nil,
            stargazersCount: 0,
            description: nil,
            fork: false,
            htmlUrl: URL(string: "https://")!
        )
        let cachedDTOPage = UserReposPage(repos: [dto], nextPage: nil)
        try await repoStore.saveReposPage(username: "octocat", page: 1, pageData: cachedDTOPage)
        try await repoStore.saveLastFetchTime(username: "octocat",
                                              ts: Date().timeIntervalSince1970)

        let result = try await useCase.getUserRepos(
            username: "octocat",
            page: 1,
            perPage: 30,
            freshnessMinutes: 30
        )

        XCTAssertEqual(result.repos.first?.name, "Sample")
        XCTAssertNil(result.nextPage)
    }

    func test_getUserRepos_fetchRemote_whenStale() async throws {
        try await repoStore.saveLastFetchTime(username: "octocat",
                                              ts: Date().timeIntervalSince1970 - 5000)

        let dto = GitHubRepoDTO(
            name: "Remote",
            language: "Swift",
            stargazersCount: 100,
            description: nil,
            fork: false,
            htmlUrl: URL(string: "https://")!
        )
        let remoteDTOPage = UserReposPage(repos: [dto], nextPage: 2)
        mockRemote.reposResult = .success(remoteDTOPage)

        let result = try await useCase.getUserRepos(
            username: "octocat",
            page: 1,
            perPage: 30,
            freshnessMinutes: 30
        )

        XCTAssertEqual(result.repos.first?.name, "Remote")
        XCTAssertEqual(result.nextPage, 2)

        let cachedDTO = try await repoStore.getReposPage(username: "octocat", page: 1)
        XCTAssertEqual(cachedDTO.repos.first?.name, "Remote")
    }

    // MARK: - User detail

    func test_getUserDetail_fetchRemote_whenStale() async throws {
        try await userStore.saveLastDetailFetchTime(username: "octocat",
                                                    ts: Date().timeIntervalSince1970 - 4000)

        let dto = GitHubUserDTO.init(login: "newuser", id: 9, avatarUrl: URL(string: "https://")!, name: "New User", followers: 5, following: 2)
        
        mockRemote.userDetailResult = .success(dto)

        let result = try await useCase.getUserDetail(
            username: "newuser",
            freshnessMinutes: 30
        )
        XCTAssertEqual(result.login, "newuser")
        XCTAssertEqual(result.name, "New User")

        let cached = try await userStore.getUserDetail(username: "newuser")
        XCTAssertEqual(cached?.login, "newuser")
    }

    func test_getUserDetail_remoteFailure_throwsError() async throws {
        mockRemote.userDetailResult = .failure(.getUser)

        do {
            _ = try await useCase.getUserDetail(
                username: "octocat",
                freshnessMinutes: 0
            )
            XCTFail("Expected failedToGetPublicUsers error")
        } catch let err as GetUsersUseCaseError {
            XCTAssertEqual(err, .failedToGetPublicUsers)
        }
    }
}
