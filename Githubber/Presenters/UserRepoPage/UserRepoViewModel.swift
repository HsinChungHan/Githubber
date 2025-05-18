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

    // MARK: - Outputs
    private(set) var userDetail: UserDetail?
    private(set) var repos: [Repo] = []

    // MARK: - Callbacks
    var onDetailUpdate: (() -> Void)?
    var onReposUpdate: (() -> Void)?
    var onError: ((Error) -> Void)?

    init(username: String,
         useCase: GetUsersUseCaseProtocol,
         remoteRepo: RemoteUserRepositoryProtocol) {
        self.username   = username
        self.useCase    = useCase
        self.remoteRepo = remoteRepo
    }

    /// 同時載入使用者資料 & Repo 清單
    func loadAll() {
        fetchDetail()
        fetchRepos()
    }

    private func fetchDetail() {
        Task {
            let result = await remoteRepo.fetchUser(username: username)
            switch result {
            case .success(let dto):
                let detail = UserDetail(
                    username: dto.login,
                    fullName: dto.name,
                    avatarURL: dto.avatarUrl,
                    followers: dto.followers,
                    following: dto.following
                )
                DispatchQueue.main.async {
                    self.userDetail = detail
                    self.onDetailUpdate?()
                }
            case .failure(let err):
                DispatchQueue.main.async { self.onError?(err) }
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
                    self.repos = page.repos   // 已由 RemoteUserRepository 過濾掉 fork
                    self.onReposUpdate?()
                }
            } catch {
                DispatchQueue.main.async { self.onError?(error) }
            }
        }
    }
}

