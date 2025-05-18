//
//  SearchUsersResponseDTO.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation

// MARK: - Search users response  (/search/users)
struct SearchUsersResponseDTO: Decodable {
    let totalCount: Int          // total_count → totalCount
    let incompleteResults: Bool  // incomplete_results → incompleteResults
    let items: [SearchUserDTO]

    private enum CodingKeys: String, CodingKey {
        case totalCount       = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}
