//
//  GitHubRepoDTO.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation

// MARK: - Repository item  (/users/{username}/repos)
struct GitHubRepoDTO: Codable {
    let name: String
    let language: String?
    let stargazersCount: Int     // stargazers_count → stargazersCount
    let description: String?
    let fork: Bool
    let htmlUrl: URL             // html_url → htmlUrl

    private enum CodingKeys: String, CodingKey {
        case name, language, description, fork
        case stargazersCount = "stargazers_count"
        case htmlUrl         = "html_url"
    }
}
