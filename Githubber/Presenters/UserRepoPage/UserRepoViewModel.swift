//
//  UserRepoViewModel.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation

/// 使用者詳細資料的純 Domain Model
struct UserDetail {
    let username: String
    let fullName: String?
    let avatarURL: URL
    let followers: Int
    let following: Int
}

final class UserRepoViewModel {

    // MARK: - Inputs
    let username: String
    private let useCase: GetUsersUseCaseProtocol
    private let remoteRepo: RemoteUserRepositoryProtocol
    private let favoriteUseCase: FavoriteReposUseCaseProtocol

    // MARK: - Outputs
    private(set) var userDetail: UserDetail?
    private(set) var repos: [Repo] = []

    // MARK: - Callbacks
    var onDetailUpdate: (() -> Void)?
    var onReposUpdate: (() -> Void)?
    var onError: ((Error) -> Void)?

    init(username: String,
         useCase: GetUsersUseCaseProtocol,
         remoteRepo: RemoteUserRepositoryProtocol,
         favoriteUseCase: FavoriteReposUseCaseProtocol) {
        self.username        = username
        self.useCase         = useCase
        self.remoteRepo      = remoteRepo
        self.favoriteUseCase = favoriteUseCase
    }

    func loadAll() {
        fetchDetail()
        fetchRepos()
    }

    func avatarData(from url: URL) async throws -> Data {
        try await useCase.getUserAvatarData(from: url)
    }
    
    func favoriteRepo(_ repo: Repo) {
        Task {
            do {
                try await favoriteUseCase.addFavorite(repo)
            } catch {
                await MainActor.run {
                    self.onError?(error)
                }
            }
        }
    }
}

// MARK: - Private helpers
extension UserRepoViewModel {
    private func fetchDetail() {
        Task {
            do {
                let dto = try await useCase.getUserDetail(
                    username: username,
                    freshnessMinutes: 10
                )
                let detail = UserDetail(
                    username: dto.login,
                    fullName: dto.name,
                    avatarURL: dto.avatarUrl,
                    followers: dto.followers,
                    following: dto.following
                )
                await MainActor.run {
                    self.userDetail = detail
                    self.onDetailUpdate?()
                }
            } catch {
                await MainActor.run {
                    self.onError?(error)
                }
            }
        }
    }

    private func fetchRepos() {
        Task {
            do {
                let page = try await useCase.getUserRepos(
                    username: username,
                    page: 1,
                    perPage: 100,
                    freshnessMinutes: 10
                )
                DispatchQueue.main.async {
                    self.repos = page.repos
                    self.onReposUpdate?()
                }
            } catch {
                DispatchQueue.main.async { self.onError?(error) }
            }
        }
    }
}
 
