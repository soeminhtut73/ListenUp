//
//  APIService.swift
//  ListenUp
//
//  Created by S M H  on 16/10/2025.
//

import UIKit

class APIService {
    static let shared = APIService()
    
    // MARK: - Categories
    
    func fetchCategories() async throws -> [MusicCategory] {
        let endpoint = URL(string: APIEndpoint.categories.fullPath)!

        let (data, _) = try await URLSession.shared.data(from: endpoint)
        let response = try JSONDecoder().decode(APIResponse<[MusicCategory]>.self, from: data)
        return response.data
    }
    
    // MARK: - Ringtones
    
    func fetchRingtones(categoryId: Int, page: Int = 1) async throws -> PaginatedData<Ringtone> {
        let endpoint = URL(string: APIEndpoint.categoryRingtones(categoryId: categoryId, page: page).fullPath)!
        
        let (data, _) = try await URLSession.shared.data(from: endpoint)
        let response = try JSONDecoder().decode(PaginatedResponse<Ringtone>.self, from: data)
        return response.data
    }
    
    func fetchRingtoneDetail(id: Int) async throws -> Ringtone {
        let endpoint = URL(string: APIEndpoint.ringtoneDetail(id: id).fullPath)!
        let (data, _) = try await URLSession.shared.data(from: endpoint)
        let response = try JSONDecoder().decode(APIResponse<Ringtone>.self, from: data)
        return response.data
    }
    
    func trackDownload(ringtoneId: Int) async throws {
        let endpoint = URL(string: APIEndpoint.downloadRingtone(id: ringtoneId).fullPath)!
        var request = URLRequest(url: endpoint)
        request.httpMethod = HTTPMethod.post.rawValue
        let (_, _) = try await URLSession.shared.data(for: request)
    }
    
    func trackPlay(ringtoneId: Int) async throws {
        let endpoint = URL(string: APIEndpoint.trackPlay(id: ringtoneId).fullPath)!
        var request = URLRequest(url: endpoint)
        request.httpMethod = HTTPMethod.post.rawValue
        let (_, _) = try await URLSession.shared.data(for: request)
    }
    
    //MARK: - Register Device
    func registerDevice(deviceId: String) async throws {
        let endpoint = URL(string: APIEndpoint.registerDevice.fullPath)!
        var request = URLRequest(url: endpoint)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["device_id": deviceId])
        let (_, _) = try await URLSession.shared.data(for: request)
    }
}

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let message: String?
}

struct PaginatedResponse<T: Codable>: Codable {
    let success: Bool
    let data: PaginatedData<T>
}

struct PaginatedData<T: Codable>: Codable {
    let data: [T]
    let currentPage: Int
    let lastPage: Int
    let total: Int
    
    enum CodingKeys: String, CodingKey {
        case data
        case currentPage = "current_page"
        case lastPage = "last_page"
        case total
    }
}
