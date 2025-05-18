//
//  UserListViewController.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import Foundation
import UIKit
import SnapKit

final class UserListViewController: UIViewController {

    // MARK: - Properties
    private let viewModel: UserListViewModel
    private let remoteRepo: RemoteUserRepositoryProtocol

    private let tableView = UITableView()
    private let searchController = UISearchController(searchResultsController: nil)
    private var filteredUsers: [User] = []

    // MARK: - Init
    init(viewModel: UserListViewModel,
         remoteRepo: RemoteUserRepositoryProtocol) {
        self.viewModel    = viewModel
        self.remoteRepo   = remoteRepo
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Users"
        view.backgroundColor = .systemBackground

        configureSearchController()
        setupTableView()
        bindViewModel()
        viewModel.loadInitial()
    }

    // MARK: - Setup

    private func configureSearchController() {
        navigationItem.searchController = searchController
        definesPresentationContext = true
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search"
        searchController.searchResultsUpdater = self
    }

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.register(UserTableViewCell.self,
                           forCellReuseIdentifier: UserTableViewCell.identifier)
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.rowHeight  = 60
        tableView.tableFooterView = UIView()

        tableView.snp.makeConstraints {
            $0.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    // MARK: - Binding
    private func bindViewModel() {
        viewModel.onUpdate = { [weak self] in
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
        
        viewModel.onLoadingStatusChange = { isLoading in }
    }

    // MARK: - Helpers

    private var isFiltering: Bool {
        searchController.isActive
          && !(searchController.searchBar.text?.isEmpty ?? true)
    }

    private func user(at index: Int) -> User {
        isFiltering
          ? filteredUsers[index]
          : viewModel.users[index]
    }
}

// MARK: - UITableViewDataSource

extension UserListViewController: UITableViewDataSource {
    func tableView(_ tv: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        isFiltering
          ? filteredUsers.count
          : viewModel.users.count
    }

    func tableView(_ tv: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(
            withIdentifier: UserTableViewCell.identifier,
            for: indexPath
        ) as! UserTableViewCell

        let user = user(at: indexPath.row)
        cell.configure(with: user, avatarProvider: viewModel.avatarData(for:))

        viewModel.loadMoreIfNeeded(currentIndex: indexPath.row)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension UserListViewController: UITableViewDelegate {
    func tableView(_ tv: UITableView,
                   didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        let user = user(at: ip.row)

        let usersStore = StoreUsersRepository()
        let reposStore = StoreUsersReposRepository()
        let repoUseCase = GetUsersUseCase(
            remoteRepo: remoteRepo,
            usersStore: usersStore,
            reposStore: reposStore
        )

        let repoVM = UserRepoViewModel(
            username: user.username,
            useCase: repoUseCase,
            remoteRepo: remoteRepo, 
            favoriteUseCase: viewModel.favoriteUseCase
        )
        let repoVC = UserRepoViewController(viewModel: repoVM)
        navigationController?.pushViewController(repoVC, animated: true)
    }
}

// MARK: - UISearchResultsUpdating

extension UserListViewController: UISearchResultsUpdating {
    func updateSearchResults(for sc: UISearchController) {
        let text = sc.searchBar.text?.lowercased() ?? ""
        filteredUsers = viewModel.users.filter {
            $0.username.lowercased().contains(text)
        }
        tableView.reloadData()
    }
}
