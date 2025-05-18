//
//  SearchUsersResponseDTO.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation
struct SearchUsersResponseDTO: Decodable {
    let total_count: Int
    let incomplete_results: Bool
    let items: [SearchUserDTO]
}
