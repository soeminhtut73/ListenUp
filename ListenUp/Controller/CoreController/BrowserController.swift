
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

protocol BrowserControllerDelegate: AnyObject {
    func didTapDownloadButton(url: URL)
}

class BrowserController: UIViewController {
    
    //MARK: - Properties
    
    static weak var shared: BrowserController?
    
    var webView: WKWebView = {
        let ucc = WKUserContentController()
        ucc.addUserScript(WebViewScripts.autoResumeScript)
        
        let cfg = WKWebViewConfiguration()
        cfg.userContentController = ucc
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = [] // user taps play once → you may resume
        return WKWebView(frame: .zero, configuration: cfg)
    }()
    
    private var lastWatchURL: String?
    
    private let searchBar = UISearchBar()
    private var progressView = UIProgressView(progressViewStyle: .default)
    private var pendingMediaURL: URL?
    private var pendingMediaType: String?
    
    private lazy var urlField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter URL or search"
        tf.keyboardType = .URL
        tf.autocapitalizationType = .none
        tf.returnKeyType = .go
        tf.delegate = self
        return tf
    }()
    
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

//        installAutoResumeAudioScript(into: webView)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Optional: wire lock-screen play/pause to page media
        wireRemoteCommands()
        
        // Example start page
        webView.load(URLRequest(url: URL(string: "https://m.youtube.com")!))
        
//        configureWebView()
//        configureUI()
//        configureSearchBar()
        
    }
    
    // Favorite toggle button
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "★",
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(toggleFavorite))
    }
    
    // FIXME: -
    private func installAutoResumeAudioScript(into webView: WKWebView) {
        let js = """
        (function(){
          if (window.__autoResumeInstalled) return; window.__autoResumeInstalled = true;
        
          function pickMedia(){
            return document.querySelector('audio') || document.querySelector('video');
          }
        
          async function tryPlay(){
            var el = pickMedia(); if (!el) return false;
            try {
              el.muted = false;
              el.autoplay = true;
              el.preload = 'auto';
              el.setAttribute('playsinline','');
              await el.play();
              return true;
            } catch(e){ return false; }
          }
        
          var pending = false;
          function schedule(){
            if (pending) return;
            pending = true;
            setTimeout(function(){ pending = false; tryPlay(); }, 120);
          }
        
          // Public hook callable from Swift
          window.__forceResumeAudio = function(){ schedule(); return true; };
        
          // If page pauses on background, try resuming
          document.addEventListener('visibilitychange', function(){
            if (document.visibilityState === 'hidden') schedule();
          }, true);
        
          // Extra lifecycle hooks
          window.addEventListener('pagehide', function(){ schedule(); }, true);
          window.addEventListener('freeze', function(){ schedule(); }, true);
        
          // If media emits pause-like signals near background, try again
          ['pause','suspend','waiting','stalled'].forEach(function(evt){
            document.addEventListener(evt, function(e){
              var t = e && e.target;
              if (t && (t.tagName === 'AUDIO' || t.tagName === 'VIDEO')) schedule();
            }, true);
          });
        })();
        """;
        
        let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(script)
    }
    
    /// Call this right before the app resigns active (from SceneDelegate)
    func ensureAudioResumeBeforeBackground() {
        let js = "__forceResumeAudio && __forceResumeAudio();"
        webView.evaluateJavaScript(js, completionHandler: nil)
        // fire twice with a tiny delay to “win” any page visibility handlers
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    // Optional: improve UX with lock-screen commands
    private func wireRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.webView.evaluateJavaScript("document.querySelector('audio,video')?.play()")
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.webView.evaluateJavaScript("document.querySelector('audio,video')?.pause()")
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.webView.evaluateJavaScript("""
            (function(){
              var m=document.querySelector('audio,video'); if(!m) return false;
              if(m.paused){m.play();} else {m.pause();}
              return true;
            })();
          """)
            return .success
        }
    }
    
    // FIXME: -
    
    //MARK: - HelperFunctions
    
    private func configureUI() {
        title = "Browser"
        
        view.addSubview(webView)
        view.addSubview(progressView)
        view.addSubview(urlField)
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        urlField.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            
            urlField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            urlField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            urlField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            urlField.heightAnchor.constraint(equalToConstant: 40),
            
            progressView.topAnchor.constraint(equalTo: urlField.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
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
        userContent.addUserScript(WebViewScripts.autoResumeScript)
//        userContent.addUserScript(WebViewScripts.trackerScript)
//        userContent.addUserScript(WebViewScripts.jsUserScript)
//        userContent.addUserScript(WebViewScripts.mediaScript)
//        userContent.add(self, name: "pageURL")
//        userContent.add(self, name: "mediaEvent")
        
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
        
        // Remote commands (play/pause via page video element)

        let cmd = MPRemoteCommandCenter.shared()
        cmd.playCommand.addTarget { [weak self] _ in self?.webView.evaluateJavaScript("document.querySelector('video,audio')?.play()"); return .success }
        
        cmd.pauseCommand.addTarget { [weak self] _ in self?.webView.evaluateJavaScript("document.querySelector('video,audio')?.pause()"); return .success }
        
        cmd.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.webView.evaluateJavaScript("""
                  (function(){
                    var m=document.querySelector('audio,video'); if(!m) return false;
                    if(m.paused){m.play();} else {m.pause();}
                    return true;
                  })();
                """)
                return .success
            }
        
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
        urlField.text = s
    }
    
    func ensurePlaybackBeforeBackground() {
        let js = """
          (function(){
            var el = document.querySelector('video, audio');
            if(!el) return false;
            try { el.muted = false; el.play().catch(()=>{}); } catch(e){}
            // Try PiP for VIDEO to survive background on some sites
            if (el.tagName === 'VIDEO' &&
                document.pictureInPictureEnabled &&
                !document.pictureInPictureElement) {
              try { el.requestPictureInPicture().catch(()=>{}); } catch(_){}
            }
            return true;
          })();
        """
        // Run immediately and a tick later to race visibility handlers
        webView.evaluateJavaScript(js, completionHandler: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    // Bridge play/pause to page <video> (best-effort)
    private func jsPlay()  {
        webView.evaluateJavaScript("document.querySelector('video')?.play()")
    }
    
    private func jsPause() {
        webView.evaluateJavaScript("document.querySelector('video')?.pause()")
    }
    
    private func jsToggle() {
        webView.evaluateJavaScript("""
          (function(){
            var v=document.querySelector('video'); if(!v) return false;
            if(v.paused){v.play();} else {v.pause();}
            return true;
          })();
        """)
    }
    
    private func updateNowPlaying(title: String, site: String) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: site
          ]
    }
    
//    private func configureSearchBar() {
//        searchBar.placeholder = "Enter URL"
//        searchBar.delegate = self
//        searchBar.autocapitalizationType = .none
//        searchBar.keyboardType = .URL
//        searchBar.returnKeyType = .go
//        searchBar.showsCancelButton = false
//        searchBar.translatesAutoresizingMaskIntoConstraints = false
//        searchBar.backgroundColor = .white
//        searchBar.searchBarStyle = .minimal
//        searchBar.backgroundImage = UIImage()
//        searchBar.searchTextField.leftViewMode = .never
//        view.addSubview(searchBar)
//        
//        progressView.translatesAutoresizingMaskIntoConstraints = false
//        progressView.trackTintColor = .clear
//        progressView.progressTintColor = .blue
//        view.addSubview(progressView)
//        view.addSubview(backButton)
//        
//        // searchBar pinned to bottom safe area
//        NSLayoutConstraint.activate([
//            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 38),
//            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            searchBar.heightAnchor.constraint(equalToConstant: 54),
//            
//            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            progressView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
//            progressView.heightAnchor.constraint(equalToConstant: 2),
//            
//            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
//            backButton.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
//            backButton.widthAnchor.constraint(equalToConstant: 30),
//            backButton.heightAnchor.constraint(equalToConstant: 30)
//        ])
//
//        // Keep the searchBar above the keyboard
//        view.keyboardLayoutGuide.topAnchor.constraint(equalTo: searchBar.bottomAnchor).isActive = true
//    }
    
    private func downloadMedia(from url: String, mediaType: String, mediaTitle: String) {
        
        
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
    
    @objc private func toggleFavorite() {
        guard let u = webView.url else { return }
        RealmService.shared.toggleFavorite(url: u, title: webView.title ?? u.absoluteString)
    }
    
    //MARK: - Media Download Prompt
    private func promptDownloadOptions(for url: String, mediaType: String, mediaTitle: String) {
        
        // Show action sheet with Download, Copy Link, Cancel
        let alert = UIAlertController(title: "Download Media?",
                                      message: mediaType,
                                      preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Download", style: .default, handler: { _ in
            // FIXME: - Need to implement downloadMedia
            
            self.downloadMedia(from: url, mediaType: mediaType, mediaTitle: mediaTitle)
        }))
        
        alert.addAction(UIAlertAction(title: "Copy Link", style: .default, handler: { _ in
            UIPasteboard.general.string = self.lastWatchURL
            self.showAlert(title: "Success", message: "Link copied to clipboard")
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
}

//MARK: - WKUserScriptHandler
extension BrowserController: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        guard let body = message.body as? [String: Any] else { return }
        
        if message.name == "mediaEvent" {
//            guard let mediaType = body["type"] as? String else { return }
//            let mediaTitle = body["title"] as? String ?? "nil"
            
//            if let lastWatchURL = lastWatchURL {
//                DispatchQueue.main.async { [weak self] in
//                    self?.promptDownloadOptions(for: lastWatchURL, mediaType: mediaType, mediaTitle: mediaTitle)
//                }
//            }
            
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
        urlField.text = webView.url?.absoluteString
        title = webView.title
        
        // Save to history
        if let u = webView.url {
//            RealmService.shared.addHistory(url: u, title: webView.title ?? u.host ?? "Page")
            print("Debug: update now : \(webView.title ?? "")")
            updateNowPlaying(title: webView.title ?? "Playing", site: u.host ?? "")
        }
    }
    
//    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
//        if let url = navigationAction.request.url {
//            print("Debug: Navigation to actual URL: \(url)")
//        }
//        decisionHandler(.allow)
//    }
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



