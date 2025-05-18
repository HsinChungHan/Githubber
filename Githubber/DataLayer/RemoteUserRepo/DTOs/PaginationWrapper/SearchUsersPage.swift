//
//  SearchUsersPage.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation
struct SearchUsersPage {
    let items: [SearchUserDTO]
    let totalCount: Int
    let nextPage: Int?
}
