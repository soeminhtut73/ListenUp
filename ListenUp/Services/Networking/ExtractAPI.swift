//
//  ExtractAPI.swift
//  ListenUp
//
//  Created by S M H  on 01/09/2025.
//

import Foundation

struct ExtractResponse: Codable {
    let title: String
    let ext: String
    let url: String
    let isHLS: Bool  // add this because backend returns isHLS
    let duration: Int
    let thumb: String  // add this because backend returns thumb
    
    var isTooLong: Bool { duration > 1200 }
}

enum ExtractAPI {
//    static let baseURL = URL(string: "http://192.168.1.20/api/yt/extract")! // for local
//    static let baseURL = URL(string: "http://192.168.1.101")!
    
    static func extract(from url: String, completion: @escaping (Result<ExtractResponse, Error>) -> Void) {
        guard let endpoint = URL(string: "http://192.168.10.65:8000/api/yt/extract") else { return }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["url": url])
        
        URLSession.shared.dataTask(with: request) { data, resp, error in
            if let err = error {
                completion(.failure(err))
                print("Debug: got error \(err)")
                return
            }
            
            guard let data = data else {
                print("Debug: data is nil.")
                return
            }
            
            do {
                completion(.success(try JSONDecoder().decode(ExtractResponse.self, from: data)))
            } catch let err {
                completion(.failure(err))
            }
        }.resume()
    }
}
