//
//  RepoPage.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation
struct ReposPage {
    let repos: [Repo]
    let nextPage: Int?       // 下一頁的 page，nil → 無更多
}
