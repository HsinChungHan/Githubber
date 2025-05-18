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
    
    /// to cancel loading avatar task
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
        // cancel any loading avatar task
        avatarLoadTask?.cancel()
        avatarImageView.image = nil
        usernameLabel.text = nil
    }

    /// Configure cell with a User and an async avatar data provider
    func configure(with user: User, avatarProvider: @escaping (URL) async throws -> Data) {
        usernameLabel.text = user.username
        avatarLoadTask?.cancel()
        avatarImageView.image = nil
        avatarLoadTask = Task {
            do {
                let data = try await avatarProvider(user.avatarURL)
                guard !Task.isCancelled else { return }
                
                if let img = UIImage(data: data) {
                    DispatchQueue.main.async { [weak self] in
                        self?.avatarImageView.image = img
                    }
                }
            } catch {
                print("Failed to load avatar:", error)
            }
        }
    }
}

