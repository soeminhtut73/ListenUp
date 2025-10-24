//
//  FileHelper.swift
//  ListenUp
//
//  Created by S M H  on 01/10/2025.
//

import Foundation

enum FileHelper {
    /// Documents directory URL
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    static func videosDir() -> URL {
        let dir = documentsDirectory.appendingPathComponent("videos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    static func audiosDir() -> URL {
        let dir = documentsDirectory.appendingPathComponent("audios", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    static func uniqueURL(in dir: URL, base: String, ext: String) -> URL {
        var url = dir.appendingPathComponent("\(base).\(ext)")
        var i = 1
        while FileManager.default.fileExists(atPath: url.path) {
            url = dir.appendingPathComponent("\(base)-\(i).\(ext)")
            i += 1
        }
        return url
    }
    
    static func fileSize(at url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }
    
    /// Build full file URL for a stored relative path
    static func fileURL(for relativePath: String?) -> URL? {
        guard let rel = relativePath, !rel.isEmpty else { return nil }
        
        let u = URL(fileURLWithPath: rel)
        if u.isFileURL && FileManager.default.fileExists(atPath: u.path) {
            return u
        } else {
            return documentsDirectory.appendingPathComponent(rel).standardizedFileURL
        }
    }
    
    
}


