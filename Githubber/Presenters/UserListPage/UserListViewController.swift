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
    
    private let viewModel: UserListViewModel
    private let tableView = UITableView()
    private lazy var footerIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = true
        view.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 44)
        return view
    }()
    
    init(viewModel: UserListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "GitHub Users"
        view.backgroundColor = .systemBackground
        
        setupTableView()
        bindViewModel()
        viewModel.loadInitial()
    }

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.register(UserTableViewCell.self, forCellReuseIdentifier: UserTableViewCell.identifier)
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.rowHeight  = 60
        tableView.tableFooterView = footerIndicator
        
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func bindViewModel() {
        viewModel.onUpdate = { [weak self] in
            self?.tableView.reloadData()
        }
        viewModel.onError = { [weak self] error in
            let alert = UIAlertController(title: "Error",
                                          message: error.localizedDescription,
                                          preferredStyle: .alert)
            alert.addAction(.init(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
        viewModel.onLoadingStatusChange = { [weak self] isLoading in
            DispatchQueue.main.async {
                if isLoading {
                    self?.footerIndicator.startAnimating()
                } else {
                    self?.footerIndicator.stopAnimating()
                }
            }
        }
    }
}

extension UserListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.users.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: UserTableViewCell.identifier,
            for: indexPath
        ) as! UserTableViewCell

        let user = viewModel.users[indexPath.row]
        cell.configure(with: user)
        viewModel.loadMoreIfNeeded(currentIndex: indexPath.row)
        return cell
    }
}

extension UserListViewController: UITableViewDelegate {}
