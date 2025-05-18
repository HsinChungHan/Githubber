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
    func getUsers(cursor: Int,
                  perPage: Int,
                  freshnessMinutes: Int) async throws -> UsersPage

    func getUserRepos(username: String,
                      page: Int,
                      perPage: Int,
                      freshnessMinutes: Int) async throws -> ReposPage
    
    func getUserAvatarData(from url: URL) async throws -> Data
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

    func getUsers(cursor: Int,
                  perPage: Int,
                  freshnessMinutes: Int) async throws -> UsersPage {

        let now  = Date().timeIntervalSince1970
        let last = try await usersStore.getLastFetchTime()

        let dtoPage: PublicUsersPage = try await withCheckedThrowingContinuation { cont in
            Task {
                do {
                    let page: PublicUsersPage
                    if needsRefresh(lastFetch: last, now: now, maxAge: freshnessMinutes) {
                        page = try await fetchUsersRemoteAndUpdate(cursor: cursor,
                                                                   perPage: perPage,
                                                                   now: now)
                    } else if let cached = try? await usersStore.getUsersPage(cursor: cursor) {
                        page = cached
                    } else {
                        page = try await fetchUsersRemoteAndUpdate(cursor: cursor,
                                                                   perPage: perPage,
                                                                   now: now)
                    }
                    cont.resume(returning: page)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }

        // 轉換成 Domain Model
        let domainUsers = dtoPage.users.map { dto in
            User(id: dto.id,
                 username: dto.login,
                 avatarURL: dto.avatarUrl)    // :contentReference[oaicite:2]{index=2}:contentReference[oaicite:3]{index=3}
        }
        return UsersPage(users: domainUsers,
                         nextSince: dtoPage.nextSince)
    }

    // MARK: - User repos list

    func getUserRepos(username: String,
                      page: Int,
                      perPage: Int,
                      freshnessMinutes: Int) async throws -> ReposPage {

        let now  = Date().timeIntervalSince1970
        let last = try await reposStore.getLastFetchTime(username: username)

        let dtoPage: UserReposPage = try await withCheckedThrowingContinuation { cont in
            Task {
                do {
                    let pageData: UserReposPage
                    if needsRefresh(lastFetch: last, now: now, maxAge: freshnessMinutes) {
                        pageData = try await fetchReposRemoteAndUpdate(user: username,
                                                                       page: page,
                                                                       perPage: perPage,
                                                                       now: now)
                    } else if let cached = try? await reposStore.getReposPage(username: username, page: page) {
                        pageData = cached
                    } else {
                        pageData = try await fetchReposRemoteAndUpdate(user: username,
                                                                       page: page,
                                                                       perPage: perPage,
                                                                       now: now)
                    }
                    cont.resume(returning: pageData)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }

        let domainRepos = dtoPage.repos.map { dto in
            Repo(name: dto.name,
                 language: dto.language,
                 stars: dto.stargazersCount,
                 description: dto.description,
                 url: dto.htmlUrl)
        }
        return ReposPage(repos: domainRepos,
                         nextPage: dtoPage.nextPage)
    }

    // MARK: - Private helpers

    private func needsRefresh(lastFetch: TimeInterval,
                              now: TimeInterval,
                              maxAge: Int) -> Bool {
        (now - lastFetch) > Double(maxAge * 60)
    }

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

// MARK: - User Avatar
extension GetUsersUseCase {
    func getUserAvatarData(from url: URL) async throws -> Data {
        let key = url.absoluteString
        if let cached = try await usersStore.getUserAvatar(url: key) {
            return cached
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        try await usersStore.saveUserAvatar(url: key, data: data)
        return data
    }
}
