//
//  UsersPageContainer.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation

struct UsersPageContainer: Codable {
    let users: [SearchUserDTO]
    let nextSince: Int?
}
