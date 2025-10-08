//
//  BrowserController.swift
//  ListenUp
//
//  Created by S M H  on 04/06/2025.
//

import UIKit
import MediaPlayer
import WebBrowser
import WebKit
import RealmSwift
import AVKit
import AVFoundation

protocol BrowserControllerDelegate: AnyObject {
    func didTapDownloadButton(url: URL)
}

class BrowserController: UIViewController {
    
    //MARK: - Properties
    
    static weak var shared: BrowserController?
    
    var webView: WKWebView = WKWebView()
    
    private var lastWatchURL: String?
    
    private let searchBar = UISearchBar()
    private var progressView = UIProgressView(progressViewStyle: .default)
    private var pendingMediaURL: URL?
    private var pendingMediaType: String?
    
    private lazy var backButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        btn.backgroundColor = .white
        btn.tintColor = UIColor.blue
        btn.addTarget(self, action: #selector(handleBackButton), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    weak var delegate: BrowserControllerDelegate?
    
    //MARK: - LifeCycle
    
    override func loadView() {
        view = UIView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureWebView()
        configureUI()
        configureSearchBar()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true) // cleanly closes the keyboard
    }
    
    //MARK: - HelperFunctions
    
    private func configureUI() {
        view.addSubview(webView)
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 54),
        ])
    }
    
    private func setupRealm() {
        
        let config = Realm.Configuration(
            schemaVersion: 1,
            migrationBlock: { migration, oldSchemaVersion in
                // Handle migration if needed
            }
        )
        Realm.Configuration.defaultConfiguration = config
            
    }
    
    private func configureWebView() {
        
        // 1. Create a user-content controller and add your scripts
        let userContent = WKUserContentController()
        userContent.addUserScript(WebViewScripts.trackerScript)
        userContent.addUserScript(WebViewScripts.jsUserScript)
        userContent.addUserScript(WebViewScripts.mediaScript)
        userContent.add(self, name: "pageURL")
        userContent.add(self, name: "mediaEvent")
        
        // 2. Create a WKWebViewConfiguration that uses it
        let config = WKWebViewConfiguration()
        config.userContentController = userContent
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []  // for autoplay
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        
        webView.addObserver(self,
                            forKeyPath: #keyPath(WKWebView.estimatedProgress),
                            options: .new,
                            context: nil)
        
        load("https://www.youtube.com")
        
    }
    
    private func load(_ input: String) {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.contains("://") {
            // Treat as URL or search
            if s.contains(".") { s = "https://\(s)" }
            else {
                let q = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
                s = "https://www.google.com/search?q=\(q)"
            }
        }
        if let url = URL(string: s) { webView.load(URLRequest(url: url)) }
    
    }
    
    private func configureSearchBar() {
        searchBar.placeholder = "Enter URL"
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.keyboardType = .URL
        searchBar.returnKeyType = .go
        searchBar.showsCancelButton = false
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.backgroundColor = .white
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundImage = UIImage()
        searchBar.searchTextField.leftViewMode = .never
        view.addSubview(searchBar)
        
        progressView.trackTintColor = .clear
        progressView.progressTintColor = .blue
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(progressView)
        view.addSubview(backButton)
        
        // searchBar pinned to bottom safe area
        NSLayoutConstraint.activate([
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 38),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: 54),
            
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backButton.trailingAnchor.constraint(equalTo: searchBar.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            backButton.heightAnchor.constraint(equalToConstant: 54)
        ])

        // Keep the searchBar above the keyboard
        view.keyboardLayoutGuide.topAnchor.constraint(equalTo: searchBar.bottomAnchor).isActive = true
    }
    
    private func downloadMedia(from url: String, mediaType: String, mediaTitle: String) {
        // FIXME: - ExtractAPI
        print("Debug: url : \(url)")
        ExtractAPI.extract(from: url) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    self.showAlert(title: "Oop!", message: "Extract Fail \(error)!")
                    
                case .success(let resp):
                    if resp.isTooLong {
                        self.showAlert(title: "Oop!", message: "Choose no longer than 10 minutes!")
                        return
                    }
                    
                    guard let safeUrl = URL(string: resp.url) else {
                        return
                    }
                    
                    print("Debug: extract success , ready to download.")
                    DownloadManager.shared.enqueue(url: safeUrl, title: resp.title, thumbURL: resp.thumb)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    deinit {
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
    
    // MARK: – KVO for progress
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            progressView.progress = Float(webView.estimatedProgress)
            progressView.isHidden = webView.estimatedProgress >= 1
        }
    }

    //MARK: - Selector
    @objc func handleBackButton() {
        webView.goBack()
    }
    
    //MARK: - Media Download Prompt
    private func promptDownloadOptions(for url: String, mediaType: String, mediaTitle: String) {
        
        let alert = UIAlertController(title: "Download Media?",
                                      message: mediaType,
                                      preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Download", style: .default, handler: { _ in
            self.downloadMedia(from: url, mediaType: mediaType, mediaTitle: mediaTitle)
        }))
        
        alert.addAction(UIAlertAction(title: "Copy Link", style: .default, handler: { _ in
            UIPasteboard.general.string = self.lastWatchURL
            self.showAlert(title: "Success", message: "Link copied to clipboard")
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func playVideo(from url: URL) {
        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player

        // Present the video player
        DispatchQueue.main.async {
            self.present(playerViewController, animated: true) {
                player.play()
            }
        }
    }
    
    func playInApp(with url: String) {
        ExtractAPI.extract(from: url) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    self.showAlert(title: "Oop!", message: "Extract Fail \(error)!")
                    
                case .success(let resp):
                    if resp.isTooLong {
                        self.showAlert(title: "Oop!", message: "Video longer than 10 minutes!")
                        return
                    }
                    
                    guard let url = URL(string: resp.url) else {
                        return
                    }
                    
                    // 1) Pause the page player to avoid double audio
                    self.webView.evaluateJavaScript("document.querySelector('video,audio')?.pause()")
                    
                    self.playVideo(from: url)

                }
            }
        }
    }
    
    private func switchNowPlayingTab() {
        if let tab = self.tabBarController {
            // assume now playing is at index 2, adjust to your order
            tab.selectedIndex = 2
        }
    }
    
}

//MARK: - WKUserScriptHandler
extension BrowserController: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        guard let body = message.body as? [String: Any] else { return }
        
        if message.name == "mediaEvent" {
            guard let mediaType = body["type"] as? String else { return }
            let mediaTitle = body["title"] as? String ?? "nil"
            
            
            
            if let lastWatchURL = lastWatchURL {
                DispatchQueue.main.async { [weak self] in
                    self?.promptDownloadOptions(for: lastWatchURL, mediaType: mediaType, mediaTitle: mediaTitle)
                }
            }
            
        } else {
            
            if let dict = message.body as? [String: Any],
               let href = dict["href"] as? String {
//                let reason = dict["reason"] as? String ?? "-"
                
                lastWatchURL = href
//                print("Debug: 🌐 pageURL:", href, "(reason:", reason, ")")
            } else if let href = message.body as? String {
                print("Debug: 🌐 pageURL:", href)
            }
        }
    }
}

// MARK: – WKNavigationDelegate
extension BrowserController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        title = webView.title
        
        // Save to history
//        if let u = webView.url {
//            RealmService.shared.addHistory(url: u, title: webView.title ?? u.host ?? "Page")
//            print("Debug: update now : \(webView.title ?? "")")
//        }
    }
    
}

//MARK: - UITextFieldDelegate
extension BrowserController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if let text = textField.text, !text.isEmpty {
            load(text)
        }
        return true
    }
}

//MARK: - UISearchResultUpdating
extension BrowserController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
//        searchBar.text = webView.url?.absoluteString
    }
}

//MARK: - UISearchBarDelegate
extension BrowserController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        
        searchBar.resignFirstResponder()
        guard var text = searchBar.text, !text.isEmpty else { return }
        
        // Add scheme if missing
        if !text.contains("://") {
            text = "https://\(text).com"
            print("Debug: searchBar text : \(text)")
            
            if let url = URL(string: text) {
                webView.load(URLRequest(url: url))
            }
        }
//        guard let url = URL(string: text) else { return }
//        webView.load(URLRequest(url: url))
    }
}



