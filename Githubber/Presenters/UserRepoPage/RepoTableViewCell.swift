//
//  RepoTableViewCell.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation
import UIKit
import SnapKit

// MARK: - RepoTableViewCell

final class RepoTableViewCell: UITableViewCell {
    static let identifier = "RepoTableViewCell"

    private let langBadge: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = .white
        l.backgroundColor = .systemBlue
        l.layer.cornerRadius = 4
        l.clipsToBounds = true
        return l
    }()
    
    private let nameLabel = UILabel()
    private let descLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14)
        l.textColor = .secondaryLabel
        l.numberOfLines = 2
        return l
    }()
    
    private let starImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "star.fill"))
        iv.tintColor = .systemGray
        return iv
    }()
    
    private let starCountLabel = UILabel()

    override init(style: UITableViewCell.CellStyle,
                  reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        // 1. 固定左右 16pt padding
        contentView.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        let margin = contentView.layoutMarginsGuide
        
        [langBadge, nameLabel, descLabel, starImageView, starCountLabel]
          .forEach { contentView.addSubview($0) }

        // badge
        langBadge.snp.makeConstraints {
            $0.top.equalTo(margin.snp.top)
            $0.leading.equalTo(margin)
            $0.height.equalTo(20)
        }

        // repo name
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(langBadge.snp.trailing).offset(8)
            $0.trailing.lessThanOrEqualTo(starImageView.snp.leading).offset(-8)
            $0.centerY.equalTo(langBadge)
        }

        // description
        descLabel.snp.makeConstraints {
            $0.top.equalTo(langBadge.snp.bottom).offset(4)
            $0.leading.equalTo(margin)
            $0.trailing.equalTo(margin)
            $0.bottom.lessThanOrEqualTo(margin)
        }

        // star count
        starCountLabel.font = .systemFont(ofSize: 14)
        starCountLabel.snp.makeConstraints {
            $0.trailing.equalTo(margin.snp.trailing)
            $0.centerY.equalTo(nameLabel)
        }
        
        // star icon
        starImageView.snp.makeConstraints {
            $0.trailing.equalTo(starCountLabel.snp.leading).offset(-4)
            $0.centerY.equalTo(nameLabel)
            $0.size.equalTo(16)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with repo: Repo) {
        let langText = (repo.language?.isEmpty == false) ? repo.language! : "None"
        langBadge.text = " \(langText) "
        langBadge.isHidden = false
        nameLabel.text      = repo.name
        descLabel.text      = repo.description
        starCountLabel.text = "\(repo.stars)"
    }
}
