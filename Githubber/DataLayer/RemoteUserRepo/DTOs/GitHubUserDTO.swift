//
//  GitHubUserDTO.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation

// MARK: - Single user detail  (/users/{username})
struct GitHubUserDTO: Decodable {
    let login: String
    let id: Int
    let avatarUrl: URL           // avatar_url → avatarUrl
    let name: String?
    let followers: Int
    let following: Int

    private enum CodingKeys: String, CodingKey {
        case login, id, name, followers, following
        case avatarUrl = "avatar_url"
    }
}
