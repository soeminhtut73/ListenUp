//
//  PrivacyViewController.swift
//  ListenUp
//
//  Created by S M H  on 08/11/2025.
//

import UIKit
import WebKit

final class PrivacyViewController: UIViewController {

    private let webView = WKWebView()

    // change this to your real URL
    private let privacyURLString = "http://192.168.10.7:8000/privacy-policy"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Privacy Policy"
        view.backgroundColor = .systemBackground

        setupWebView()
        loadPrivacyPage()
    }

    private func setupWebView() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadPrivacyPage() {
        guard let url = URL(string: privacyURLString) else { return }
        let request = URLRequest(url: url)
        webView.load(request)
    }
}
