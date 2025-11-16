//
//  RewardWallet.swift
//  ListenUp
//
//  Created by S M H  on 14/11/2025.
//
import Foundation

final class RewardWallet {
    static let shared = RewardWallet()
    private init() {}

    // MARK: - Keys
    private let downloadKey   = "downloadTokens"
    
    // MARK: - Stored balances
    
    var downloadTokens: Int {
        get { UserDefaults.standard.integer(forKey: downloadKey) }
        set { UserDefaults.standard.set(newValue, forKey: downloadKey) }
    }

    
    // MARK: - Download reward logic
    func grantDownloadTokens() {
        // Every ad unlocks 4 downloads
        downloadTokens += 4
    }
    
    func consumeDownloadToken() -> Bool {
        print("Debug: Before cosume : \(downloadTokens)")
        guard downloadTokens > 0 else { return false }
        downloadTokens -= 1
        print("Debug: After cosume : \(downloadTokens)")
        return true
    }

    // Optional helpers
    func resetAll() {
        downloadTokens = 0
    }
}
