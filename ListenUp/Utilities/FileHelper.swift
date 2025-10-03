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
    
    /// Build full file URL for a stored relative path
    static func fileURL(for relativePath: String?) -> URL? {
        guard let rel = relativePath, !rel.isEmpty else { return nil }
//        return documentsDirectory.appendingPathComponent(rel, isDirectory: false).standardizedFileURL
        
        let u = URL(fileURLWithPath: rel)
        if u.isFileURL && FileManager.default.fileExists(atPath: u.path) {
            return u
        } else {
            return documentsDirectory.appendingPathComponent(rel).standardizedFileURL
        }
    }
    
    
}


