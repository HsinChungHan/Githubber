//
//  ReposPageContainer.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation

struct ReposPageContainer: Codable {
    let repos: [GitHubRepoDTO]
    let nextPage: Int?
}
