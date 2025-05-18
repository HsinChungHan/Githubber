//
//  GitHubAPIE2ETests.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import XCTest
@testable import Githubber

final class GitHubAPIE2ETests: XCTestCase {

    // MARK: - Properties
    private var token: String!

    // MARK: - Lifecycle
    override func setUpWithError() throws {
        guard let pat = ProcessInfo.processInfo.environment["GITHUB_PAT"], !pat.isEmpty else {
            throw XCTSkip("⚠️ Environment variable GITHUB_PAT not set – skipping E2E tests")
        }
        token = pat
    }

    // MARK: - Tests ----------------------------------------------------------

    /// Covers:
    /// 1. GET /users/{username}
    /// 2. GET /users/{username}/repos
    func testFetchUserAndRepos() async throws {
        // 1. Fetch single user
        let user: GitHubUserDTO = try await fetchJSON(
            request: makeRequest(path: "/users/octocat")
        )
        XCTAssertEqual(user.login, "octocat")
        XCTAssertGreaterThan(user.followers, 0)

        // 2. Fetch user repos and filter out forks
        let repos: [GitHubRepoDTO] = try await fetchJSON(
            request: makeRequest(
                path: "/users/octocat/repos",
                queryItems: [
                    .init(name: "type", value: "owner"),
                    .init(name: "sort", value: "updated"),
                    .init(name: "per_page", value: "100")
                ]),
            as: [GitHubRepoDTO].self
        ).filter { !$0.fork }

        XCTAssertTrue(repos.contains { $0.name == "Hello-World" })
        if let first = repos.first {
            XCTAssertGreaterThanOrEqual(first.stargazersCount, 0)
        }
    }

    /// Covers: GET /search/users
    func testSearchUsers() async throws {
        // Build query: login contains "tom" and followers > 100
        let query = "tom in:login followers:>100"

        let req = makeRequest(
            path: "/search/users",
            queryItems: [
                .init(name: "q", value: query),
                .init(name: "per_page", value: "30")
            ])

        let result: SearchUsersResponseDTO = try await fetchJSON(request: req)

        // Assertions
        XCTAssertGreaterThan(result.items.count, 0, "Should find at least one user")
        for user in result.items.prefix(10) {
            XCTAssertTrue(user.login.lowercased().contains("tom"),
                          "\(user.login) does not contain 'tom'")
        }
        XCTAssertGreaterThan(result.totalCount, 0)
        XCTAssertFalse(result.incompleteResults, "incomplete_results should be false")
    }

    /// Covers: GET /users  (public user listing)
    func testListPublicUsers() async throws {
        let req = makeRequest(
            path: "/users",
            queryItems: [
                .init(name: "since", value: "0"),
                .init(name: "per_page", value: "100")
            ])

        let users: [SearchUserDTO] = try await fetchJSON(request: req)

        XCTAssertFalse(users.isEmpty, "Response should not be empty")
        XCTAssertLessThanOrEqual(users.count, 100, "Exceeds per_page limit")

        // IDs should be in ascending order
        let ids = users.map(\.id)
        XCTAssertEqual(ids, ids.sorted(), "User IDs should be ascending")

        // Basic field sanity check (first 10 users)
        for user in users.prefix(10) {
            XCTAssertFalse(user.login.isEmpty)
            XCTAssertNotNil(URL(string: user.avatarUrl.absoluteString))
        }
    }

    // MARK: - Networking Helpers --------------------------------------------

    private func makeURL(path: String,
                         queryItems: [URLQueryItem] = []) -> URL {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host   = "api.github.com"
        comps.path   = path
        comps.queryItems = queryItems.isEmpty ? nil : queryItems
        return comps.url!
    }

    private func makeRequest(path: String,
                             queryItems: [URLQueryItem] = []) -> URLRequest {
        var req = URLRequest(url: makeURL(path: path, queryItems: queryItems))
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("token \(token!)", forHTTPHeaderField: "Authorization")
        return req
    }

    private func fetchJSON<T: Decodable>(request req: URLRequest,
                                         as type: T.Type = T.self) async throws -> T {
        print("➡️ Requesting URL: \(req.url!.absoluteString)")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            XCTFail("GitHub API returned HTTP \(code)")
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
