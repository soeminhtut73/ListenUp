//
//  BrowserController.swift
//  ListenUp
//
//  Created by S M H  on 04/06/2025.
//

import UIKit
import MediaPlayer
import WebKit
import RealmSwift

protocol BrowserControllerDelegate: AnyObject {
    func didTapDownloadButton(url: URL)
}

class BrowserController: UIViewController {
    
    // MARK: - Properties
    
    // Singleton reference
    static weak var shared: BrowserController?
    
    // Delegate
    weak var delegate: BrowserControllerDelegate?
    
    // WebView
    private(set) var webView: WKWebView!
    
    // Download tracking
    private var lastWatchURL: String?
    private var pendingMediaURL: URL?
    private var pendingMediaType: String?
    
    // MARK: - UI Components
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Enter URL"
        searchBar.autocapitalizationType = .none
        searchBar.keyboardType = .URL
        searchBar.returnKeyType = .go
        searchBar.showsCancelButton = false
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.backgroundColor = .white
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundImage = UIImage()
        searchBar.searchTextField.leftViewMode = .never
        return searchBar
    }()
    
    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.trackTintColor = .clear
        progress.progressTintColor = .systemBlue
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        button.backgroundColor = .white
        button.tintColor = .systemBlue
        button.addTarget(self, action: #selector(handleBackButton), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = UIView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupUI()
        setupSearchBar()
        loadInitialPage()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }
    
    deinit {
        cleanupObservers()
    }
    
    // MARK: - Setup
    
    private func setupWebView() {
        // Create user content controller
        let userContent = WKUserContentController()
        userContent.addUserScript(WebViewScripts.trackerScript)
        userContent.addUserScript(WebViewScripts.jsUserScript)
        userContent.addUserScript(WebViewScripts.mediaScript)
        userContent.add(self, name: "pageURL")
        userContent.add(self, name: "mediaEvent")
        
        // Create configuration
        let config = WKWebViewConfiguration()
        config.userContentController = userContent
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Initialize WebView
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add observer for progress
        webView.addObserver(
            self,
            forKeyPath: #keyPath(WKWebView.estimatedProgress),
            options: .new,
            context: nil
        )
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(webView)
        view.addSubview(progressView)
        view.addSubview(searchBar)
        view.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            // WebView
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: searchBar.topAnchor),
            
            // Progress View
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            // Back Button (Left side)
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 54),
            backButton.heightAnchor.constraint(equalToConstant: 54),
            backButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Search Bar (Right side, same height)
            searchBar.leadingAnchor.constraint(equalTo: backButton.trailingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchBar.heightAnchor.constraint(equalTo: backButton.heightAnchor),
            searchBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        
        // Keep search bar above keyboard
        view.keyboardLayoutGuide.topAnchor.constraint(equalTo: searchBar.bottomAnchor).isActive = true
    }
    
    private func setupSearchBar() {
        searchBar.delegate = self
    }
    
    private func loadInitialPage() {
        loadURL("https://www.youtube.com")
    }
    
    private func cleanupObservers() {
        webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
    
    // MARK: - Navigation
    
    private func loadURL(_ input: String) {
        var urlString = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if input has a scheme
        if !urlString.contains("://") {
            if urlString.contains(".") {
                // Looks like a URL - add https
                urlString = "https://\(urlString)"
            } else {
                // Treat as search query
                let encodedQuery = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
                urlString = "https://www.google.com/search?q=\(encodedQuery)"
            }
        }
        
        guard let url = URL(string: urlString) else {
            showMessage(withTitle: "Invalid URL", message: "Please enter a valid URL or search term")
            return
        }
        
        webView.load(URLRequest(url: url))
    }
    
    // MARK: - KVO Observer
    
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == #keyPath(WKWebView.estimatedProgress) {
            updateProgress()
        }
    }
    
    private func updateProgress() {
        let progress = Float(webView.estimatedProgress)
        progressView.progress = progress
        progressView.isHidden = progress >= 1.0
    }
    
    // MARK: - Download Management
    
    private func downloadMedia(from url: String) {
        DownloadGuard.checkAndProceed(from: self) { [weak self] decision in
            guard let self = self else { return }
            
            switch decision {
            case .proceed:
                self.performDownload(with: url)
            case .cancelled:
                self.showMessage(withTitle: "Cancelled", message: "Download was cancelled")
            }
        }
    }
    
    private func performDownload(with url: String) {
        ExtractAPI.extract(from: url) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    print("Debug: Extract failed - \(error.localizedDescription)")
                    self.showMessage(withTitle: "Oops!", message: "Unauthorized to download!")
                    
                case .success(let response):
                    self.handleExtractSuccess(response)
                }
            }
        }
    }
    
    private func handleExtractSuccess(_ response: ExtractResponse) {
        // Check duration limit
        if response.isTooLong {
            showMessage(withTitle: "Duration Limit", message: "Please choose media no longer than 10 minutes")
            return
        }
        
        // Validate URL
        guard let mediaURL = URL(string: response.url) else {
            showMessage(withTitle: "Invalid URL", message: "Could not parse media URL")
            return
        }
        
        // Enqueue download
        DownloadManager.shared.enqueue(
            url: mediaURL,
            title: response.title,
            thumbURL: response.thumb,
            duration: response.duration
        )
    }
    
    // MARK: - Media Download Prompt
    
    private func promptDownloadOptions(for url: String, mediaType: String, mediaTitle: String) {
        let alert = UIAlertController(
            title: "Download Media?",
            message: "\(mediaType)\n\(mediaTitle)",
            preferredStyle: .alert
        )
        
        // Download Action
        alert.addAction(UIAlertAction(title: "Download", style: .default) { [weak self] _ in
            self?.downloadMedia(from: url)
        })
        
        // Copy Link Action
        alert.addAction(UIAlertAction(title: "Copy Link", style: .default) { [weak self] _ in
            guard let self = self else { return }
            UIPasteboard.general.string = self.lastWatchURL
            self.showMessage(withTitle: "Success", message: "Link copied to clipboard")
        })
        
        // Cancel Action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - Actions
    
    @objc private func handleBackButton() {
        if webView.canGoBack {
            webView.goBack()
        }
    }
}

// MARK: - WKScriptMessageHandler

extension BrowserController: WKScriptMessageHandler {
    
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any] else {
            print("Debug: Invalid message body format")
            return
        }
        
        switch message.name {
        case "mediaEvent":
            handleMediaEvent(body)
            
        case "pageURL":
            handlePageURL(body)
            
        default:
            print("Debug: Unknown message name: \(message.name)")
        }
    }
    
    private func handleMediaEvent(_ body: [String: Any]) {
        guard let mediaType = body["type"] as? String else {
            print("Debug: Media event missing type")
            return
        }
        
        let mediaTitle = body["title"] as? String ?? "Untitled"
        
        guard let lastWatchURL = lastWatchURL else {
            print("Debug: No lastWatchURL available")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.promptDownloadOptions(
                for: lastWatchURL,
                mediaType: mediaType,
                mediaTitle: mediaTitle
            )
        }
    }
    
    private func handlePageURL(_ body: [String: Any]) {
        if let href = body["href"] as? String {
            lastWatchURL = href
            print("Debug: 🌐 Page URL updated: \(href)")
        }
    }
}

// MARK: - WKNavigationDelegate

extension BrowserController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Update title
        title = webView.title
        
        // Update search bar
        searchBar.text = webView.url?.absoluteString
        
        print("Debug: Page loaded - \(webView.title ?? "No title")")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Debug: Navigation failed - \(error.localizedDescription)")
        progressView.isHidden = true
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressView.isHidden = false
        print("Debug: Navigation started")
    }
}

// MARK: - UISearchBarDelegate

extension BrowserController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        
        guard let text = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return
        }
        
        loadURL(text)
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        // Select all text for easy editing
        searchBar.searchTextField.selectAll(nil)
    }
}

// MARK: - UISearchResultsUpdating

extension BrowserController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchBar.text = webView.url?.absoluteString
    }
}



