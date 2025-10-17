//
//  APIService.swift
//  ListenUp
//
//  Created by S M H  on 16/10/2025.
//

import UIKit

class APIService {
    static let shared = APIService()
    
//    private let baseURL = "https://your-api.com/api/v1"
    private let baseURL = "http://192.168.10.65:8000/api/v1"
    
    // MARK: - Categories
    
    func fetchCategories() async throws -> [MusicCategory] {
        let url = URL(string: "\(baseURL)/categories")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(APIResponse<[MusicCategory]>.self, from: data)
        return response.data
    }
    
    // MARK: - Ringtones
    
    func fetchRingtones(categoryId: Int, page: Int = 1) async throws -> PaginatedData<Ringtone> {
        let url = URL(string: "\(baseURL)/categories/\(categoryId)/ringtones?page=\(page)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(PaginatedResponse<Ringtone>.self, from: data)
        return response.data
    }
    
    func fetchRingtoneDetail(id: Int) async throws -> Ringtone {
        let url = URL(string: "\(baseURL)/ringtones/\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(APIResponse<Ringtone>.self, from: data)
        return response.data
    }
    
    func trackDownload(ringtoneId: Int) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/ringtones/\(ringtoneId)/download")!)
        request.httpMethod = "POST"
        let (_, _) = try await URLSession.shared.data(for: request)
    }
    
    func trackPlay(ringtoneId: Int) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/ringtones/\(ringtoneId)/play")!)
        request.httpMethod = "POST"
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
