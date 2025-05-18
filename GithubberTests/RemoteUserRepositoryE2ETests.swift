//
//  RemoteUserRepositoryE2ETests.swift
//  GithubberTests
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import XCTest
@testable import Githubber         // Module containing DTOs & repos itory
@testable import RHNetworkAPI           // Networking abstraction

final class RemoteUserRepositoryE2ETests: XCTestCase {

    private var repo: RemoteUserRepositoryProtocol!

    override func setUpWithError() throws {
        let pat = ProcessInfo.processInfo.environment["GITHUB_PAT"] // optional
        repo = RemoteUserRepository(pat: pat)
    }

    // MARK: - /users
    /// GET /users — first page (cursor = 0)
    func test_fetchPublicUsers_firstPage_success() async throws {
        let result = await repo.fetchPublicUsers(since: 0, perPage: 50)
        switch result {
        case .success(let page):
            XCTAssertFalse(page.users.isEmpty)
            XCTAssertLessThanOrEqual(page.users.count, 50)
            XCTAssertNotNil(page.nextSince, "nextSince should be present for page-1")
        case .failure:
            XCTFail("GET /users failed")
        }
    }

    /// Cursor pagination on /users
    func test_fetchPublicUsers_pagination_nextPage() async throws {
        let page1 = try await repo.fetchPublicUsers(since: 0, perPage: 30).get()
        guard let cursor = page1.nextSince else { throw XCTSkip("No next page") }

        let page2 = try await repo.fetchPublicUsers(since: cursor, perPage: 30).get()

        // Safely unwrap the first IDs from each page
        guard
            let firstIDPage1 = page1.users.first?.id,
            let firstIDPage2 = page2.users.first?.id
        else {
            XCTFail("Missing user IDs in response")
            return
        }

        XCTAssertNotEqual(firstIDPage1, firstIDPage2, "First IDs of page 1 and 2 must differ")
    }

    // MARK: - /search/users
    /// GET /search/users — first page
    func test_searchUsers_firstPage_success() async throws {
        let q = "swift in:login followers:>50"
        let result = await repo.searchUsers(query: q, page: 1, perPage: 20)
        switch result {
        case .success(let page):
            XCTAssertFalse(page.items.isEmpty)
            XCTAssertGreaterThan(page.totalCount, 0)
            XCTAssertNotNil(page.nextPage, "nextPage should be present")
        case .failure:
            XCTFail("Search API failed")
        }
    }

    /// Page-based pagination on /search/users
    /// Page-based pagination on /search/users
    func test_searchUsers_pagination_nextPage() async throws {
        let query = "tom in:login"
        let page1 = try await repo.searchUsers(query: query, page: 1, perPage: 10).get()
        guard let next = page1.nextPage else { throw XCTSkip("Only one page available") }

        let page2 = try await repo.searchUsers(query: query, page: next, perPage: 10).get()

        // Safely unwrap the first IDs from each page
        guard
            let firstIDPage1 = page1.items.first?.id,
            let firstIDPage2 = page2.items.first?.id
        else {
            XCTFail("Missing user IDs in one of the pages")
            return
        }

        XCTAssertNotEqual(firstIDPage1, firstIDPage2,
                          "First user IDs of page 1 and page \(next) should differ")
    }


    // MARK: - /users/{username}
    /// GET /users/{username}
    func test_fetchUser_detail_success() async throws {
        let result = await repo.fetchUser(username: "octocat")
        switch result {
        case .success(let user):
            XCTAssertEqual(user.login, "octocat")
            XCTAssertGreaterThan(user.followers, 0)
        case .failure:
            XCTFail("GET /users/{username} failed")
        }
    }

    // MARK: - /users/{username}/repos
    /// GET /users/{username}/repos — first page, non-fork only
    func test_fetchUserRepos_firstPage_success() async throws {
        let result = await repo.fetchUserRepos(username: "octocat", page: 1, perPage: 50)
        switch result {
        case .success(let page):
            XCTAssertFalse(page.repos.isEmpty)
            XCTAssertNil(page.repos.first { $0.fork }, "Forked repos should be filtered out")
        case .failure:
            XCTFail("GET /users/{username}/repos failed")
        }
    }

    /// Page-based pagination on /users/{username}/repos
    func test_fetchUserRepos_pagination_nextPage() async throws {
        let page1 = try await repo.fetchUserRepos(username: "apple", page: 1, perPage: 30).get()
        guard let next = page1.nextPage else { throw XCTSkip("Repo list fits in one page") }

        let page2 = try await repo.fetchUserRepos(username: "apple", page: next, perPage: 30).get()

        guard
            let firstRepoPage1 = page1.repos.first?.name,
            let firstRepoPage2 = page2.repos.first?.name
        else {
            XCTFail("Missing repo names in response")
            return
        }

        XCTAssertNotEqual(firstRepoPage1, firstRepoPage2, "First repo names of page 1 and 2 must differ")
    }
}
