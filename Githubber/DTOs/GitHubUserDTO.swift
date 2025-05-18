//
//  GitHubUserDTO.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation
struct GitHubUserDTO: Decodable {
    let login: String
    let id: Int
    let avatar_url: URL
    let name: String?
    let followers: Int
    let following: Int
}
