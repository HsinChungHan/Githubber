//
//  SearchUsersUseCase.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation

// MARK: - Errors
enum SearchUsersUseCaseError: Error {
    case failedToSearchUsers
}

// MARK: - Protocol
protocol SearchUsersUseCaseProtocol {
    /// Always fetch from network
    func searchUsers(query: String,
                     page: Int,
                     perPage: Int) async throws -> SearchUsersPage
}

// MARK: - Implementation
final class SearchUsersUseCase: SearchUsersUseCaseProtocol {

    private let remoteRepo: RemoteUserRepositoryProtocol
    
    init(remoteRepo: any RemoteUserRepositoryProtocol) {
        self.remoteRepo = remoteRepo
    }
    
    func searchUsers(query: String,
                     page: Int,
                     perPage: Int) async throws -> SearchUsersPage {
        
        let result = await remoteRepo.searchUsers(query: query,
                                                  page: page,
                                                  perPage: perPage)
        
        switch result {
        case .success(let pageData):
            return pageData
        case .failure:
            throw SearchUsersUseCaseError.failedToSearchUsers
        }
    }
}
