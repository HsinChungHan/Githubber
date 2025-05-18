//
//  GetUsersUseCase.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation

// MARK: - Errors
enum GetUsersUseCaseError: Error {
    case failedToGetPublicUsers
    case failedToSavePublicUsers
    case failedToGetUserRepos
    case failedToSaveUserRepos
}

// MARK: - Protocol
protocol GetUsersUseCaseProtocol {
    func getPublicUsers(cursor: Int,
                        perPage: Int,
                        freshnessMinutes: Int) async throws -> PublicUsersPage

    func getUserRepos(username: String,
                      page: Int,
                      perPage: Int,
                      freshnessMinutes: Int) async throws -> UserReposPage
}

// MARK: - Implementation
final class GetUsersUseCase: GetUsersUseCaseProtocol {

    // Dependencies
    private let remoteRepo: RemoteUserRepositoryProtocol
    private let usersStore: StoreUsersRepositoryProtocol
    private let reposStore: StoreUsersReposRepositoryProtocol

    init(remoteRepo: RemoteUserRepositoryProtocol,
         usersStore: StoreUsersRepositoryProtocol,
         reposStore: StoreUsersReposRepositoryProtocol) {
        self.remoteRepo = remoteRepo
        self.usersStore = usersStore
        self.reposStore = reposStore
    }

    // MARK: - Public users list

    func getPublicUsers(cursor: Int,
                        perPage: Int,
                        freshnessMinutes: Int) async throws -> PublicUsersPage {

        let now  = Date().timeIntervalSince1970
        let last = try await usersStore.getLastFetchTime()

        if needsRefresh(lastFetch: last, now: now, maxAge: freshnessMinutes) {
            return try await fetchUsersRemoteAndUpdate(cursor: cursor,
                                                       perPage: perPage,
                                                       now: now)
        } else if let cached = try? await usersStore.getUsersPage(cursor: cursor) {
            return cached
        } else {
            return try await fetchUsersRemoteAndUpdate(cursor: cursor,
                                                       perPage: perPage,
                                                       now: now)
        }
    }

    // MARK: - User repos list

    func getUserRepos(username: String,
                      page: Int,
                      perPage: Int,
                      freshnessMinutes: Int) async throws -> UserReposPage {

        let now  = Date().timeIntervalSince1970
        let last = try await reposStore.getLastFetchTime(username: username)

        if needsRefresh(lastFetch: last, now: now, maxAge: freshnessMinutes) {
            return try await fetchReposRemoteAndUpdate(user: username,
                                                       page: page,
                                                       perPage: perPage,
                                                       now: now)
        } else if let cached = try? await reposStore.getReposPage(username: username, page: page) {
            return cached
        } else {
            return try await fetchReposRemoteAndUpdate(user: username,
                                                       page: page,
                                                       perPage: perPage,
                                                       now: now)
        }
    }

    // MARK: - Private helpers

    /// Determine if cache is older than allowed max age.
    private func needsRefresh(lastFetch: TimeInterval,
                              now: TimeInterval,
                              maxAge: Int) -> Bool {
        (now - lastFetch) > Double(maxAge * 60)
    }

    /// Fetch `/users` page, save to cache, return.
    private func fetchUsersRemoteAndUpdate(cursor: Int,
                                           perPage: Int,
                                           now: TimeInterval) async throws -> PublicUsersPage {

        let result = await remoteRepo.fetchPublicUsers(since: cursor, perPage: perPage)
        switch result {
        case .success(let page):
            try await usersStore.saveUsersPage(cursor: cursor, page: page)
            try await usersStore.saveLastFetchTime(now)
            return page
        case .failure:
            throw GetUsersUseCaseError.failedToGetPublicUsers
        }
    }

    /// Fetch `/users/{username}/repos` page, save to cache, return.
    private func fetchReposRemoteAndUpdate(user username: String,
                                           page: Int,
                                           perPage: Int,
                                           now: TimeInterval) async throws -> UserReposPage {

        let result = await remoteRepo.fetchUserRepos(username: username,
                                                     page: page,
                                                     perPage: perPage)
        switch result {
        case .success(let pageData):
            try await reposStore.saveReposPage(username: username,
                                               page: page,
                                               pageData: pageData)
            try await reposStore.saveLastFetchTime(username: username, ts: now)
            return pageData
        case .failure:
            throw GetUsersUseCaseError.failedToGetUserRepos
        }
    }
}
