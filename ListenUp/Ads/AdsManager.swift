//
//  AdsManager.swift
//  ListenUp
//
//  Created by S M H  on 14/11/2025.
//

import GoogleMobileAds
import AdSupport
import CryptoKit

enum AdsManager {
    static func configure() {
        #if DEBUG
//        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
//        let hash = Insecure.MD5.hash(data: idfa.data(using: .utf8)!)
//        let testDeviceID = hash.map { String(format: "%02hhx", $0) }.joined()
//        print("Debug: testDeviceID : \(testDeviceID)")
        
        let ids = ["SIMULATOR", "9f89c84a559f573636a47ff8daed0d33"]
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ids
        #endif
        
        MobileAds.shared.start()
    }
}

