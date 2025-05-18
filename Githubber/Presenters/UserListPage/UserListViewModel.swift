//
//  UserListViewModel.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation

/// ViewModel only exposes domain models externally and does not depend on any DTO
final class UserListViewModel {
    
    // MARK: - Dependencies
    private let useCase: GetUsersUseCaseProtocol    // Directly calls getUsers(cursor:perPage:freshnessMinutes:)
    private let perPage: Int                        // Number of items to fetch per page
    
    // MARK: - Pagination State
    private var nextCursor: Int? = 0               // Cursor for pagination
    private(set) var isLoading = false             // Indicates if a fetch is in progress
    
    // MARK: - Data exposed to View
    private(set) var users: [User] = []            // User is a domain model
    
    // MARK: - Callbacks
    var onUpdate: (() -> Void)?                    // Called when data is updated
    var onError: ((Error) -> Void)?                // Called when an error occurs
    
    // MARK: - Init
    init(useCase: GetUsersUseCaseProtocol,
         perPage: Int = 30) {
        self.useCase = useCase
        self.perPage = perPage
    }
    
    // MARK: - Public
    
    /// Load the first page of users
    func loadInitial() {
        users.removeAll()
        nextCursor = 0
        fetchNext()
    }
    
    /// Load the next page when the last item is displayed
    func loadMoreIfNeeded(currentIndex: Int) {
        guard !isLoading,
              let cursor = nextCursor,
              currentIndex >= users.count - 1 else {
            return
        }
        fetchNext()
    }
    
    // MARK: - Private
    
    private func fetchNext() {
        guard let cursor = nextCursor, !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                // Call the use case to fetch the paginated domain model
                let page = try await useCase.getUsers(
                    cursor: cursor,
                    perPage: perPage,
                    freshnessMinutes: 5
                )
                
                // Update local state and notify the view
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.users.append(contentsOf: page.users)
                    self.nextCursor = page.nextSince
                    self.isLoading = false
                    self.onUpdate?()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.isLoading = false
                    self?.onError?(error)
                }
            }
        }
    }
}
