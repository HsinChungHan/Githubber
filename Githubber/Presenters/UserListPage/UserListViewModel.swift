//
//  UserListViewModel.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

// UserListViewModel.swift

import Foundation

/// ViewModel only exposes domain models externally.
final class UserListViewModel {
    
    // MARK: - Dependencies
    let useCase: GetUsersUseCaseProtocol
    let favoriteUseCase: FavoriteReposUseCaseProtocol
    private let perPage: Int
    
    // MARK: - Pagination State
    private var nextCursor: Int? = 0
    private(set) var isLoading = false
    
    // MARK: - Data exposed to View
    private(set) var users: [User] = []
    
    // MARK: - Callbacks
    var onUpdate: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onLoadingStatusChange: ((Bool) -> Void)?    // ← 新增
    
    // MARK: - Init
    init(useCase: GetUsersUseCaseProtocol,
         favoriteUseCase: FavoriteReposUseCaseProtocol,
         perPage: Int = 30) {
        self.useCase = useCase
        self.favoriteUseCase = favoriteUseCase
        self.perPage = perPage
    }
    
    // MARK: - Public
    
    func loadInitial() {
        users.removeAll()
        nextCursor = 0
        fetchNext()
    }
    
    func loadMoreIfNeeded(currentIndex: Int) {
        guard !isLoading,
              let cursor = nextCursor,
              currentIndex >= users.count - 1 else {
            return
        }
        fetchNext()
    }
    
    // MARK: - Internal methods
    func avatarData(for url: URL) async throws -> Data {
        try await useCase.getUserAvatarData(from: url)
    }
}

// MARK: - Private helpers
extension UserListViewModel {
    private func fetchNext() {
        guard let cursor = nextCursor, !isLoading else { return }
        isLoading = true
        // notify loading started
        DispatchQueue.main.async { [weak self] in
            self?.onLoadingStatusChange?(true)
        }
        
        Task {
            do {
                let page = try await useCase.getUsers(
                    cursor: cursor,
                    perPage: perPage,
                    freshnessMinutes: 5
                )
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.users.append(contentsOf: page.users)
                    self.nextCursor = page.nextSince
                    self.isLoading = false
                    // notify loading ended
                    self.onLoadingStatusChange?(false)
                    self.onUpdate?()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.isLoading = false
                    // notify loading ended
                    self?.onLoadingStatusChange?(false)
                    self?.onError?(error)
                }
            }
        }
    }
}
