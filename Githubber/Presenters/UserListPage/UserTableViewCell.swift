//
//  UserTableViewCell.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import UIKit
import SnapKit

final class UserTableViewCell: UITableViewCell {
    static let identifier = "UserTableViewCell"

    private let avatarImageView = UIImageView()
    private let usernameLabel   = UILabel()
    
    /// 用來取消正在進行的 avatar 載入
    private var avatarLoadTask: Task<Void, Never>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        avatarImageView.layer.cornerRadius = 20
        avatarImageView.clipsToBounds = true
        usernameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        contentView.addSubview(avatarImageView)
        contentView.addSubview(usernameLabel)
        
        avatarImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(40)
        }
        usernameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        // 1. 取消任何正在跑的 avatar 載入
        avatarLoadTask?.cancel()
        avatarImageView.image = nil
        usernameLabel.text = nil
    }

    /// Configure cell with a User and an async avatar data provider
    func configure(
        with user: User,
        avatarProvider: @escaping (URL) async throws -> Data
    ) {
        usernameLabel.text = user.username
        
        // 2. 先取消舊任務
        avatarLoadTask?.cancel()
        avatarImageView.image = nil
        
        // 3. 建立新 Task 來載入 avatar data
        avatarLoadTask = Task {
            do {
                let data = try await avatarProvider(user.avatarURL)
                // Task 被取消就不要再更新 UI
                guard !Task.isCancelled else { return }
                
                if let img = UIImage(data: data) {
                    DispatchQueue.main.async { [weak self] in
                        self?.avatarImageView.image = img
                    }
                }
            } catch {
                // 可以加上錯誤處理或 fallback 圖片
                print("Failed to load avatar:", error)
            }
        }
    }
}

