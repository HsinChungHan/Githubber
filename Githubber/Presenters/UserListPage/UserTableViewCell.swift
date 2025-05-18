//
//  UserTableViewCell.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation
import UIKit
import SnapKit

/// UITableViewCell that displays a user's avatar and username, laid out with SnapKit
final class UserTableViewCell: UITableViewCell {
    static let identifier = "UserTableViewCell"

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.layer.cornerRadius = 20
        iv.clipsToBounds = true
        return iv
    }()

    private let usernameLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 16, weight: .medium)
        return lbl
    }()

    private var imageLoadTask: URLSessionDataTask?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.image = nil
        imageLoadTask?.cancel()
    }

    func configure(with user: User) {
        usernameLabel.text = user.username
        loadImage(from: user.avatarURL)
    }

    private func loadImage(from url: URL) {
        imageLoadTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let img = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.avatarImageView.image = img
            }
        }
        imageLoadTask?.resume()
    }
}
