//
//  PublicUsersPage.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation
struct PublicUsersPage {
    let users: [SearchUserDTO]
    let nextSince: Int?      // nil → no further page
}
