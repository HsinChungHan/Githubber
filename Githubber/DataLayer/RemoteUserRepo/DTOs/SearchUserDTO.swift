//
//  SearchUserDTO.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation

// MARK: - User list item  (/users  &  /search/users items[])
struct SearchUserDTO: Codable {
    let login: String
    let id: Int
    let avatarUrl: URL           // avatar_url → avatarUrl

    private enum CodingKeys: String, CodingKey {
        case login, id
        case avatarUrl = "avatar_url"
    }
}
