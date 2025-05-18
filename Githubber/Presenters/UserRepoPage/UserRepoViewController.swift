//
//  UserRepoViewController.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

// MARK: - UserRepoViewController
import UIKit
import SnapKit

final class UserRepoViewController: UIViewController {

    private let viewModel: UserRepoViewModel
    private let tableView = UITableView()

    // Header subviews
    private let avatarImageView = UIImageView()
    private let usernameLabel   = UILabel()
    private let fullNameLabel   = UILabel()
    private let followersLabel  = UILabel()
    private let followingLabel  = UILabel()

    init(viewModel: UserRepoViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = viewModel.username

        setupTableView()
        bindViewModel()
        viewModel.loadAll()
    }

    private func setupTableView() {
        tableView.register(RepoTableViewCell.self,
                           forCellReuseIdentifier: RepoTableViewCell.identifier)
        tableView.dataSource = self
        tableView.delegate   = self

        tableView.tableHeaderView = makeTableHeader()

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func makeTableHeader() -> UIView {
        let header = UIView()
        header.backgroundColor = .systemBackground

        let followStack = UIStackView(arrangedSubviews: [followersLabel, followingLabel])
        followStack.axis = .horizontal
        followStack.spacing = 24
        followStack.alignment = .center

        [avatarImageView,
         usernameLabel,
         fullNameLabel,
         followStack].forEach { header.addSubview($0) }

        avatarImageView.layer.cornerRadius = 40
        avatarImageView.clipsToBounds = true
        avatarImageView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.centerX.equalToSuperview()
            $0.size.equalTo(80)
        }

        usernameLabel.font = .systemFont(ofSize: 20, weight: .bold)
        usernameLabel.snp.makeConstraints {
            $0.top.equalTo(avatarImageView.snp.bottom).offset(12)
            $0.centerX.equalToSuperview()
        }

        fullNameLabel.font = .systemFont(ofSize: 16)
        fullNameLabel.textColor = .secondaryLabel
        fullNameLabel.snp.makeConstraints {
            $0.top.equalTo(usernameLabel.snp.bottom).offset(4)
            $0.centerX.equalToSuperview()
        }

        followStack.snp.makeConstraints {
            $0.top.equalTo(fullNameLabel.snp.bottom).offset(12)
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().inset(8)
        }

        return header
    }

    private func updateTableHeaderHeight() {
        guard let header = tableView.tableHeaderView else { return }
        header.setNeedsLayout()
        header.layoutIfNeeded()
        let targetSize = CGSize(
            width: tableView.bounds.width,
            height: UIView.layoutFittingCompressedSize.height
        )
        let height = header.systemLayoutSizeFitting(targetSize).height
        var frame = header.frame
        frame.size.height = height
        header.frame = frame
        tableView.tableHeaderView = header
    }

    private func bindViewModel() {
        viewModel.onDetailUpdate = { [weak self] in
            guard let self = self, let d = self.viewModel.userDetail else { return }
            
            Task {
                do {
                    let data = try await self.viewModel.avatarData(from: d.avatarURL)
                    if let img = UIImage(data: data) {
                        await MainActor.run {
                            self.avatarImageView.image = img
                        }
                    }
                } catch {
                    // optionally show placeholder or ignore
                    print("Avatar load error:", error)
                }
            }
            
            self.usernameLabel.text  = d.username
            self.fullNameLabel.text  = d.fullName
            self.followersLabel.text = "\(d.followers) Followers"
            self.followingLabel.text = "\(d.following) Following"
            self.updateTableHeaderHeight()
        }
        
        viewModel.onReposUpdate = { [weak self] in
            self?.tableView.reloadData()
        }
        
        viewModel.onError = { [weak self] error in
            let alert = UIAlertController(
                title: "Error",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(.init(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }
}

// MARK: - UITableViewDataSource
extension UserRepoViewController: UITableViewDataSource {
    func tableView(_ tv: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        viewModel.repos.count
    }

    func tableView(_ tv: UITableView,
                   cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(
            withIdentifier: RepoTableViewCell.identifier,
            for: ip
        ) as! RepoTableViewCell
        cell.configure(with: viewModel.repos[ip.row])
        return cell
    }

    func tableView(_ tv: UITableView,
                   viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "Repositories"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        header.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.bottom.equalToSuperview().inset(4)
        }
        return header
    }
    
    func tableView(_ tv: UITableView,
                   heightForHeaderInSection section: Int) -> CGFloat {
        44
    }
    
    func tableView(_ tv: UITableView,
                   trailingSwipeActionsConfigurationForRowAt ip: IndexPath)
    -> UISwipeActionsConfiguration? {
        let repo = viewModel.repos[ip.row]
        let action = UIContextualAction(style: .normal, title: "Favorite") { [weak self] _, _, cb in
            self?.viewModel.favoriteRepo(repo)
            cb(true)
        }
        action.backgroundColor = .systemOrange
        return UISwipeActionsConfiguration(actions: [action])
    }
}

// MARK: - UITableViewDelegate
extension UserRepoViewController: UITableViewDelegate {
    func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        let repo = viewModel.repos[ip.row]
        let webVC = RepoWebViewController(url: repo.url)
        webVC.title = repo.name
        navigationController?.pushViewController(webVC, animated: true)
    }
}
