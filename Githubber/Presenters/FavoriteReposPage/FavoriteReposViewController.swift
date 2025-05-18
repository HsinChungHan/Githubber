//
//  FavoriteReposViewController.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import UIKit
import SnapKit

final class FavoriteReposViewController: UIViewController {

    private let viewModel: FavoriteReposViewModel
    private let tableView = UITableView()
    private let refreshControl = UIRefreshControl()

    init(viewModel: FavoriteReposViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Favorites"
        view.backgroundColor = .systemBackground
        setupTableView()
        bindViewModel()
        viewModel.loadFavorites()
    }

    private func setupTableView() {
        tableView.register(RepoTableViewCell.self,
                           forCellReuseIdentifier: RepoTableViewCell.identifier)
        tableView.dataSource = self
        tableView.delegate   = self
        
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self,
                                 action: #selector(didPullToRefresh),
                                 for: .valueChanged)

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    @objc private func didPullToRefresh() {
        viewModel.loadFavorites()
    }

    private func bindViewModel() {
        viewModel.onUpdate = { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadData()
            if self.refreshControl.isRefreshing {
                self.refreshControl.endRefreshing()
            }
        }
        
        viewModel.onError = { [weak self] error in
            if self?.refreshControl.isRefreshing == true {
                self?.refreshControl.endRefreshing()
            }
            let alert = UIAlertController(title: "Error",
                                          message: error.localizedDescription,
                                          preferredStyle: .alert)
            alert.addAction(.init(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }
}

// MARK: - UITableViewDataSource
extension FavoriteReposViewController: UITableViewDataSource {
    func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.favorites.count
    }
    func tableView(_ tv: UITableView,
                   cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(
            withIdentifier: RepoTableViewCell.identifier,
            for: ip
        ) as! RepoTableViewCell
        cell.configure(with: viewModel.favorites[ip.row])
        return cell
    }
}

// MARK: - UITableViewDelegate
extension FavoriteReposViewController: UITableViewDelegate {
    func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        let repo = viewModel.favorites[ip.row]
        let webVC = RepoWebViewController(url: repo.url)
        webVC.title = repo.name
        navigationController?.pushViewController(webVC, animated: true)
    }
    
    func tableView(_ tv: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        let repo = viewModel.favorites[indexPath.row]
        let action = UIContextualAction(style: .destructive, title: "Unfavorite") { [weak self] _, _, cb in
            self?.viewModel.unfavorite(repo)
            cb(true)
        }
        return UISwipeActionsConfiguration(actions: [action])
    }
}
