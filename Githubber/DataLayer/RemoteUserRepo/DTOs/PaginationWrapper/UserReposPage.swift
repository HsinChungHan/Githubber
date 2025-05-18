//
//  UserReposPage.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation
struct UserReposPage {
    let repos: [GitHubRepoDTO]
    let nextPage: Int?       // nil → no further page
}
