//
//  AudioConverterManager.swift
//  ListenUp
//
//  Created by S M H  on 18/10/2025.
//

import UIKit
import AVFoundation
import RealmSwift

class AudioConverter {
    static let shared = AudioConverter()
    private init() {}
    
    /// Converts a 30s audio clip from a given local video URL and saves it as an AudioItem in Realm.
    func convertToAudio(from videoURL: URL, startTime: TimeInterval, completion: @escaping (Result<URL, Error>) -> Void) {
        
        // Define output .m4a file path in app Documents directory
        let audioDir = FileHelper.audiosDir()
        let baseName = videoURL.deletingPathExtension().lastPathComponent
        let audioFileName = baseName + "_trimmed.m4a"
        let audioURL = FileHelper.uniqueURL(in: audioDir, base: audioFileName, ext: "m4a")
        
        Task {
            do {
                // Remove existing file if any
                if FileManager.default.fileExists(atPath: audioURL.path) {
                    try FileManager.default.removeItem(at: audioURL)
                }
                
                // Extract 30 seconds segment
                let outputURL = try await self.extractAudio(from: videoURL, to: audioURL, startTime: startTime, duration: 30)
                
                // Compute file info
                let fileSize = FileHelper.fileSize(at: outputURL)
//                let asset = AVURLAsset(url: outputURL)
//                let duration = try await asset.load(.duration)
//                let seconds = duration.seconds
                await MainActor.run {
                    do {
                        let realm = try Realm()
                        let newItem = DownloadItem()
                        newItem.localPath = "audios/" + outputURL.lastPathComponent
                        newItem.fileSize = fileSize
                        newItem.duration = 30
                        newItem.createdAt = Date()
                        newItem.mediaType = .audio
                        
                        try realm.write {
                            realm.add(newItem)
                        }
                    } catch {
                        completion(.failure(error))
                    }
                    completion(.success(outputURL))
                }
                
            } catch {
                print("❌ Audio conversion failed:", error)
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Extract Audio using AVAssetExportSession
    private func extractAudio(from videoURL: URL, to audioURL: URL, startTime: TimeInterval = 0, duration: TimeInterval = 0) async throws -> URL {
        
        let asset = AVURLAsset(url: videoURL)
        
        // Load asset duration safely
        let assetDuration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(assetDuration)
        
        // Clamp start & duration safely
        let safeStart = max(0, min(startTime, totalSeconds - 0.1))
        let maxDuration = totalSeconds - safeStart
        let safeDuration = min(duration, maxDuration)
        
        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw NSError(
                domain: "AudioConverter",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]
            )
        }
        
        exportSession.outputURL = audioURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: safeStart, preferredTimescale: 600),
            duration: CMTime(seconds: safeDuration, preferredTimescale: 600)
        )
        
        try await exportSession.export(to: audioURL, as: .m4a)
        
        // Verify the output file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw NSError(domain: "AudioConverter", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Export completed but file not found"
            ])
        }
        
        return audioURL
    }
    
    
    //MARK: - Audio Conversion
//    func convertToAudio(item: DownloadItem, startTime: TimeInterval = 0, completion: @escaping (Result<URL, Error>) -> Void) {
//
//        guard let videoPath = item.localPath else {
//            completion(.failure(NSError(domain: "DownloadManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Video file not found"])))
//            return
//        }
//
//        NotificationCenter.default.post(name: .audioConversionStarted, object: item.id)
//
//        let videoURL = FileHelper.documentsDirectory.appendingPathComponent(videoPath)
//        let audioDir = FileHelper.audiosDir()
//        let audioFileName = URL(fileURLWithPath: videoPath).deletingPathExtension().lastPathComponent + ".m4a"
//        let audioURL = FileHelper.uniqueURL(in: audioDir, base: audioFileName.replacingOccurrences(of: ".m4a", with: ""), ext: "m4a")
//
//        Task {
//            do {
//
//                if FileManager.default.fileExists(atPath: audioURL.path) {
//                    try FileManager.default.removeItem(at: audioURL)
//                }
//
//                let outputURL = try await extractAudio(from: videoURL, to: audioURL, startTime: startTime)
//                let relativePath = "audios/" + outputURL.lastPathComponent
//                let size = FileHelper.fileSize(at: outputURL)
//
//                let asset = AVURLAsset(url: outputURL)
//                let duration = try await asset.load(.duration)
//                let second = duration.seconds
//
//                NotificationCenter.default.post(name: .audioConversionFinished, object: item.id)
//                NotificationCenter.default.post(name: DownloadManager.didConvertToAudio, object: item.id)
//
//                await MainActor.run {
//                    self.updateRealmItem(itemId: item.id, relativePath: relativePath, size: size, duration: second)
//
//                    completion(.success(outputURL))
//                }
//            } catch {
//                print("❌ Extraction failed: \(error)")
//                print("Error details: \(error.localizedDescription)")
//
//                await MainActor.run {
//                    completion(.failure(error))
//                }
//            }
//        }
//    }
//
//    // Helper method to update Realm on correct thread
//    private func updateRealmItem(itemId: String, relativePath: String, size: Int64, duration: Double) {
//        // This runs on main thread
//        guard let realm = try? Realm() else {
//            print("❌ Failed to get Realm instance")
//            return
//        }
//
//        guard let item = realm.object(ofType: DownloadItem.self, forPrimaryKey: itemId) else {
//            print("❌ Item not found: \(itemId)")
//            return
//        }
//
//        do {
//            try realm.write {
//                item.localAudioPath = relativePath
//                item.audioFileSize = size
//                item.audioConversionDate = Date()
//                item.duration = duration
//
//                // Update media type
//                if item.localPath != nil {
//                    item.mediaType = .both
//                } else {
//                    item.mediaType = .audio
//                }
//            }
//            print("✅ Realm updated successfully")
//        } catch {
//            print("❌ Realm write failed: \(error)")
//        }
//    }
//
//    private func extractAudio(from videoURL: URL, to audioURL: URL, startTime: TimeInterval = 0) async throws -> URL {
//        let asset = AVURLAsset(url: videoURL)
//        let trimDuration: TimeInterval = 30
//
//        // Load asset duration safely
//        let assetDuration = try await asset.load(.duration)
//        let totalSeconds = CMTimeGetSeconds(assetDuration)
//
//        // Clamp start & duration safely
//        let safeStart = max(0, min(startTime, totalSeconds - 0.1))
//        let maxDuration = totalSeconds - safeStart
//        let safeDuration = min(trimDuration, maxDuration)
//
//        // Create export session
//        guard let exportSession = AVAssetExportSession(
//            asset: asset,
//            presetName: AVAssetExportPresetAppleM4A
//        ) else {
//            throw NSError(
//                domain: "AudioConverter",
//                code: 500,
//                userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]
//            )
//        }
//
//        exportSession.outputURL = audioURL
//        exportSession.outputFileType = .m4a
//        exportSession.timeRange = CMTimeRange(
//            start: CMTime(seconds: safeStart, preferredTimescale: 600),
//            duration: CMTime(seconds: safeDuration, preferredTimescale: 600)
//        )
//
//        try await exportSession.export(to: audioURL, as: .m4a)
//
//        // Verify the output file exists
//        guard FileManager.default.fileExists(atPath: audioURL.path) else {
//            throw NSError(domain: "AudioConverter", code: 500, userInfo: [
//                NSLocalizedDescriptionKey: "Export completed but file not found"
//            ])
//        }
//
//        return audioURL
//    }
}
