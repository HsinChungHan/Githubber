//
//  SearchUserDTO.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation
struct SearchUserDTO: Decodable {
    let login: String
    let id: Int
    let avatar_url: URL
}
