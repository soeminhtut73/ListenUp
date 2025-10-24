//
//  DownloadManager.swift
//  ListenUp
//
//  Created by S M H  on 03/08/2025.
//

import UIKit
import Foundation
import RealmSwift

typealias Completion = (Result<URL, Error>) -> Void

extension Notification.Name {
    static let downloadProgress = Notification.Name("downloadProgress")
    static let downloadFinished = Notification.Name("downloadFinished")
}

final class DownloadManager: NSObject, URLSessionDownloadDelegate {
    
    static let shared = DownloadManager()
    private override init() {}
    
    //MARK: - Notifications optional: HistoryController can listen for row animations)
    static let didEnqueue = Notification.Name("DownloadManager.didEnqueue")
    static let didUpdate  = Notification.Name("DownloadManager.didUpdate")
    static let didFinish  = Notification.Name("DownloadManager.didFinish")
    
    private var completion: Completion?
    var backgroundCompletionHandler: (() -> Void)?
    
    private var lastBucket: Int = -1  // 0…100
    
    // taskID -> itemID
    private var map = [Int: String]()
    private let realm = RealmService.shared
    
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.background(withIdentifier: "com.ListenUp.backgroundSession")
        cfg.sessionSendsLaunchEvents = true
        cfg.isDiscretionary = true
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()
    
    //MARK: - Enqueue
    @discardableResult
    func enqueue(url: URL, title: String, thumbURL: String?, duration: Int? = 0) -> String {
        let item = DownloadItem()
        item.title = title
        item.sourceURL = ""
        item.thumbURL = thumbURL ?? ""
        item.status = .running
        item.duration = TimeInterval(duration ?? 0)
        item.mediaType = .video
        realm.createOrUpdate(item: item)
        
        lastBucket = -1
        
        let task = session.downloadTask(with: url)
        map[task.taskIdentifier] = item.id
        task.resume()
        
        NotificationCenter.default.post(name: DownloadManager.didEnqueue, object: item.id)
        return item.id
        
    }
    
    //MARK: - URLSessionDownloadDelegate
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        guard let id = map[downloadTask.taskIdentifier] else { return }
        
        // 1) Decide final name + extension (prefer server suggestion)
        let suggested = downloadTask.response?.suggestedFilename
        let extFromSuggested = suggested.flatMap { URL(fileURLWithPath: $0).pathExtension }
        let extFromURL = downloadTask.originalRequest?.url?.pathExtension
        let ext = [extFromSuggested, extFromURL].compactMap { $0 }.first
        let finalExt = (ext?.isEmpty == false) ? ext! : "mp4"
        
        let baseName: String = {
            if let s = suggested, !s.isEmpty {
                return URL(fileURLWithPath: s).deletingPathExtension().lastPathComponent
            } else {
                return UUID().uuidString
            }
        }()
        
        
        // 2) Destination: Documents/videos/<unique name>
        let videosDir = FileHelper.videosDir()
        let dest = FileHelper.uniqueURL(in: videosDir, base: baseName, ext: finalExt)
        
        do {
            try FileManager.default.moveItem(at: location, to: dest)
            
            let relativePath = "videos/" + dest.lastPathComponent
            
            // compute size
            let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? NSNumber)?.int64Value ?? 0
            
            print("Debug: filesize : \(size)")
            
            realm.update(id) {
                $0.localPath = relativePath
                $0.fileSize  = size
                $0.progress  = 1
                $0.status    = .completed
                $0.errorMessage = nil
            }
            
            DispatchQueue.main.async {
                DownloadNotificationManager.shared.showSystemNotification()
            }
            
            NotificationCenter.default.post(name: DownloadManager.didFinish, object: id)
            
            completion?(.success(dest))
        } catch {
            realm.update(id) {
                $0.status = .failed
                $0.errorMessage = error.localizedDescription
            }
            completion?(.failure(error))
        }
        
        completion = nil
        
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let id = map[task.taskIdentifier] else { return }
        map.removeValue(forKey: task.taskIdentifier)
        if let error = error {
            RealmService.shared.update(id) {
                $0.status = .failed
                $0.errorMessage = error.localizedDescription
            }
            NotificationCenter.default.post(name: Self.didFinish, object: id)
        }
    }
    
    // Progress
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        guard totalBytesExpectedToWrite > 0, let id = map[downloadTask.taskIdentifier] else { return }
        
        let p = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        let bucket = Int((p * 100).rounded(.down))
        guard bucket != lastBucket else { return }
        lastBucket = bucket
        
        self.realm.update(id) {
            let wr = max($0.progress, min(max(p, 0), 1))
            $0.progress = wr
            $0.status = .running
        }
        NotificationCenter.default.post(name: DownloadManager.didUpdate, object: id)
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        backgroundCompletionHandler?()
        backgroundCompletionHandler = nil
    }
    
    //MARK: - Helper functions
    
}
