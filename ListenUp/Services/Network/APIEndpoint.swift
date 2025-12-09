//
//  APIEndpoint.swift
//  ListenUp
//
//  Created by S M H  on 09/11/2025.
//

import UIKit

enum APIEndpoint {
    // MARK: - Extract (v1)
    case ytExtract
    
    // MARK: - Categories (v1)
    case categories
    case categoryRingtones(categoryId: Int, page: Int)
    
    // MARK: - Ringtones (v1)
    case ringtoneDetail(id: Int)
    case downloadRingtone(id: Int)
    case trackPlay(id: Int)
    
    //MARK: - Cookie
    case uploadCookie
    
    //MARK: - Register (v1)
    case registerDevice
    
    var version: APIConfiguration.APIVersion {
        return .v1
    }
    
    var baseURL: String {
        return APIConfiguration.baseURL(for: version)
    }
    
    var fullPath: String {
        switch self {
        // extractor
        case .ytExtract:
            return "\(baseURL)/extract"
            
        // categories
        case .categories:
            return "\(baseURL)/categories"
        case .categoryRingtones(let categoryID, page: let page):
            return "\(baseURL)/categories/\(categoryID)/ringtones?page=\(page)"
            
        // ringtone
        case .ringtoneDetail(let id):
            return "\(baseURL)/ringtones/\(id)"
        case .downloadRingtone(id: let id):
            return "\(baseURL)/ringtones/\(id)/download"
        case .trackPlay(let id):
            return "\(baseURL)/ringtones/\(id)/play"
            
        // register device
        case .registerDevice:
            return "\(baseURL)/register_device_id"
            
        case .uploadCookie:
            return "\(baseURL)/upload-cookies"
        }
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
