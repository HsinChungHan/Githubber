//
//  RepoWebViewController.swift
//  Githubber
//
//  Created by Chung Han Hsin on 2025/5/18.
//

import UIKit
import WebKit
import SnapKit

final class RepoWebViewController: UIViewController {
    private let webView = WKWebView()
    private let url: URL

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        webView.load(URLRequest(url: url))
    }
}

