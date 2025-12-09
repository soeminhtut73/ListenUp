//
//  ExtractAPI.swift
//  ListenUp
//
//  Created by S M H  on 01/09/2025.
//

import Foundation

struct ExtractResponse: Codable {
    let title: String
    let url: String
    let duration: Int
    let thumb: String
    
    var isTooLong: Bool { duration > 1800 }
}

enum ExtractAPI {
    static func extract(from url: String, completion: @escaping (Result<ExtractResponse, Error>) -> Void) {
        
        guard let endpoint = URL(string: APIEndpoint.ytExtract.fullPath) else { return }
        let deviceId = DeviceID.shared.get()
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["device_id": deviceId, "url": url])
        
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
