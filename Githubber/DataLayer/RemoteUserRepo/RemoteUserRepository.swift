//
//  RemoteUserRepository.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation
import RHNetworkAPI

// MARK: - Errors
enum RemoteUserRepositoryError: Error {
    case listUsers
    case searchUsers
    case getUser
    case listRepos
}

// MARK: - Protocol
protocol RemoteUserRepositoryProtocol {
    func fetchPublicUsers(since: Int, perPage: Int) async -> Result<PublicUsersPage, RemoteUserRepositoryError>
    func searchUsers(query: String, page: Int, perPage: Int) async -> Result<SearchUsersPage, RemoteUserRepositoryError>
    func fetchUser(username: String) async -> Result<GitHubUserDTO, RemoteUserRepositoryError>
    func fetchUserRepos(username: String, page: Int, perPage: Int) async -> Result<UserReposPage, RemoteUserRepositoryError>
}

// MARK: - Repository
final class RemoteUserRepository: RemoteUserRepositoryProtocol {

    /// Underlying network client
    private let client: RHNetworkAPIProtocol

    /// Designated initializer
    /// - Parameters:
    ///   - client: External `RHNetworkAPIProtocol` instance. If `nil`, a default GitHub client will be created.
    ///   - pat:    Personal-Access-Token used only when repository creates its own client.
    init(client external: RHNetworkAPIProtocol? = nil, pat: String? = nil) {
        if let ext = external {
            // Use externally supplied client (assumed headers already set)
            self.client = ext
        } else {
            // Build default GitHub client with proper headers
            let factory   = RHNetworkAPIImplementationFactory()
            let domainURL = URL(string: "https://api.github.com")!

            var headers: [String: String] = [
                "Accept": "application/vnd.github+json"
            ]
            if let token = pat {
                headers["Authorization"] = "token \(token)"
            }

            self.client = factory.makeNonCacheAndNoneUploadProgressClient(
                with: domainURL,
                headers: headers
            )
        }
    }

    // MARK: - /users
    func fetchPublicUsers(since: Int, perPage: Int) async -> Result<PublicUsersPage, RemoteUserRepositoryError> {
        await request(
            path: "/users",
            queryItems: [
                URLQueryItem(name: "since", value: "\(since)"),
                URLQueryItem(name: "per_page", value: "\(perPage)")
            ],
            mapError: .listUsers
        ) { data, response in
            let users = try JSONDecoder().decode([SearchUserDTO].self, from: data)
            let next  = response.nextQueryValue(name: "since").flatMap(Int.init)
            return PublicUsersPage(users: users, nextSince: next)
        }
    }

    // MARK: - /search/users
    func searchUsers(query: String, page: Int, perPage: Int) async -> Result<SearchUsersPage, RemoteUserRepositoryError> {
        await request(
            path: "/search/users",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "per_page", value: "\(perPage)")
            ],
            mapError: .searchUsers
        ) { data, response in
            let dto  = try JSONDecoder().decode(SearchUsersResponseDTO.self, from: data)
            let next = response.nextQueryValue(name: "page").flatMap(Int.init)
            return SearchUsersPage(items: dto.items, totalCount: dto.totalCount, nextPage: next)
        }
    }

    // MARK: - /users/{username}
    func fetchUser(username: String) async -> Result<GitHubUserDTO, RemoteUserRepositoryError> {
        await request(
            path: "/users/\(username)",
            queryItems: [],
            mapError: .getUser
        ) { data, _ in
            try JSONDecoder().decode(GitHubUserDTO.self, from: data)
        }
    }

    // MARK: - /users/{username}/repos
    func fetchUserRepos(username: String, page: Int, perPage: Int) async -> Result<UserReposPage, RemoteUserRepositoryError> {
        await request(
            path: "/users/\(username)/repos",
            queryItems: [
                URLQueryItem(name: "type", value: "owner"),
                URLQueryItem(name: "sort", value: "updated"),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "per_page", value: "\(perPage)")
            ],
            mapError: .listRepos
        ) { data, response in
            let all  = try JSONDecoder().decode([GitHubRepoDTO].self, from: data)
            let next = response.nextQueryValue(name: "page").flatMap(Int.init)
            let repos = all.filter { !$0.fork }     // exclude forked repos
            return UserReposPage(repos: repos, nextPage: next)
        }
    }

    // MARK: - Generic Request Helper
    private func request<Output>(
        path: String,
        queryItems: [URLQueryItem],
        mapError: RemoteUserRepositoryError,
        responseMapper: @escaping (Data, HTTPURLResponse) throws -> Output
    ) async -> Result<Output, RemoteUserRepositoryError> {

        return await withCheckedContinuation { continuation in
            client.get(path: path, queryItems: queryItems) { result in
                switch result {
                case let .success(data, response):
                    do {
                        let mapped = try responseMapper(data, response)
                        continuation.resume(returning: .success(mapped))
                    } catch {
                        continuation.resume(returning: .failure(mapError))
                    }
                case .failure:
                    continuation.resume(returning: .failure(mapError))
                }
            }
        }
    }
}

// MARK: - Link-Header Utility
private extension HTTPURLResponse {
    /// Parse `rel="next"` link and return specified query value.
    func nextQueryValue(name: String) -> String? {
        guard
            let link = allHeaderFields["Link"] as? String,
            let nextPart = link
                .split(separator: ",")
                .first(where: { $0.contains("rel=\"next\"") }),
            let urlStart = nextPart.firstIndex(of: "<"),
            let urlEnd   = nextPart.firstIndex(of: ">")
        else { return nil }

        let urlString = nextPart[urlStart...urlEnd]
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))

        guard let comps = URLComponents(string: urlString) else { return nil }
        return comps.queryItems?.first(where: { $0.name == name })?.value
    }
}
