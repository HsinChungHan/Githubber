//
//  GitHubRepoDTO.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation
struct GitHubRepoDTO: Decodable {
    let name: String
    let language: String?
    let stargazers_count: Int
    let description: String?
    let fork: Bool
    let html_url: URL
}
