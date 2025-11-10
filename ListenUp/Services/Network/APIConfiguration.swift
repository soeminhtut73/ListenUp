//
//  APIConfiguration.swift
//  ListenUp
//
//  Created by S M H  on 09/11/2025.
//

import UIKit

enum Environment {
    case development
    case production
    
    #if DEBUG
    static let current: Environment = .development
    #else
    static let current: Environment = .production
    #endif
}

struct APIConfiguration {
    // MARK: - Environment Configuration
    static var baseURL: String {
        switch Environment.current {
        case .development:
            return "http://192.168.10.7:8000"
        case .production:
            return "https://api.yourapp.com"
        }
    }
    
    // MARK: - API Versioning
    enum APIVersion: String {
        case v1 = "/api/v1"
        case v2 = "/api/v2"
        
        var path: String {
            return self.rawValue
        }
    }
    
    static let defaultVersion: APIVersion = .v1
    
    // MARK: - Full Base URLs
    static func baseURL(for version: APIVersion = .v1) -> String {
        return baseURL + version.path
    }
}
