//
//  SearchUsersUseCaseTests.swift
//  GithubberTests
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import XCTest
@testable import Githubber

// MARK: - Mock RemoteUserRepository
final class MockSearchRemoteRepo: RemoteUserRepositoryProtocol {

    // Pre-set response for searchUsers only
    var searchResponse: Result<SearchUsersPage, RemoteUserRepositoryError> = .failure(.searchUsers)
    
    // Unused RemoteUserRepository methods
    func fetchPublicUsers(since: Int, perPage: Int) async -> Result<PublicUsersPage, RemoteUserRepositoryError> { .failure(.listUsers) }
    func fetchUser(username: String) async -> Result<GitHubUserDTO, RemoteUserRepositoryError> { .failure(.getUser) }
    func fetchUserRepos(username: String, page: Int, perPage: Int) async -> Result<UserReposPage, RemoteUserRepositoryError> { .failure(.listRepos) }
    func searchUsers(query: String, page: Int, perPage: Int) async -> Result<SearchUsersPage, RemoteUserRepositoryError> {
        return searchResponse
    }
}


final class SearchUsersUseCaseTests: XCTestCase {

    private var useCase: SearchUsersUseCase!
    private var mockRemote: MockSearchRemoteRepo!
    
    override func setUp() async throws {
        mockRemote = MockSearchRemoteRepo()
        useCase    = SearchUsersUseCase(remoteRepo: mockRemote)
    }
    
    override func tearDown() async throws {
        useCase    = nil
        mockRemote = nil
    }

    /// Successful search should return remote page
    func test_searchUsers_success() async throws {
        let dto  = SearchUserDTO(login: "tomcat", id: 99, avatarUrl: URL(string: "https://img")!)
        let page = SearchUsersPage(items: [dto], totalCount: 1, nextPage: nil)
        mockRemote.searchResponse = .success(page)

        let result = try await useCase.searchUsers(query: "tom", page: 1, perPage: 10)
        XCTAssertEqual(result.items.first?.login, "tomcat")
    }

    /// Failure path should throw `failedToSearchUsers`
    func test_searchUsers_failure_throwsError() async throws {
        mockRemote.searchResponse = .failure(.searchUsers)

        do {
            _ = try await useCase.searchUsers(query: "swift", page: 1, perPage: 10)
            XCTFail("Expected failedToSearchUsers error")
        } catch let err as SearchUsersUseCaseError {
            XCTAssertEqual(err, .failedToSearchUsers)
        }
    }
}
