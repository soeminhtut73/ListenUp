//
//  CookieUploader.swift
//  ListenUp
//
//  Created by S M H  on 24/11/2025.
//

import Foundation
import WebKit

final class CookieUploader {

    static let shared = CookieUploader()
    private init() {}

    func uploadCookies(deviceId: String, cookiesText: String) {
        guard let endpoint = URL(string: APIEndpoint.uploadCookie.fullPath) else { return }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        struct Payload: Encodable {
            let device_id: String
            let cookies: String
        }
        let payload = Payload(device_id: deviceId, cookies: cookiesText)
        request.httpBody = try? JSONEncoder().encode(payload)

        URLSession.shared.dataTask(with: request) { data, resp, err in
            if let err = err { print("Upload failed:", err); return }
            print("Upload response:", String(data: data ?? Data(), encoding: .utf8) ?? "No response")
        }.resume()
    }
    
    func exportCookies(completion: @escaping (String) -> Void) {
        
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        var lines: [String] = ["# Netscape HTTP Cookie File"]
        
        for cookie in cookies {
            guard cookie.domain.contains("youtube.com") else { continue }
            
            let line = [
                cookie.domain.hasPrefix(".") ? cookie.domain : "." + cookie.domain,
                "TRUE",
                cookie.path,
                cookie.isSecure ? "TRUE" : "FALSE",
                String(Int(cookie.expiresDate?.timeIntervalSince1970 ?? 0)),
                cookie.name,
                cookie.value
            ].joined(separator: "\t")
            
            lines.append(line)
        }
        
        let netscape = lines.joined(separator: "\n")
        completion(netscape)
    }
}
