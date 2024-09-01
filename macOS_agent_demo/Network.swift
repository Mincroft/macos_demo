//
//  Network.swift
//  macOS_agent_demo
//
//  Created by 殷瑜 on 2024/8/26.
//

import Foundation
import AppKit 

struct Networking {
    static let backendURL = URL(string: "http://agent2.yuantsy.com:8000")!

    static func startSession(prompt: String, frontendInfo: [String: String], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let sessionURL = backendURL.appendingPathComponent("sessions")
        var request = URLRequest(url: sessionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "prompt": prompt,
            "frontend_info": frontendInfo,
            "is_script": true,
            "is_script_link": false,
            "script_name_link": "Script_mac_DownloadGithubZip"
        ]
        
        printFrontendInfo(frontendInfo)

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Error serializing payload: \(error)")
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error)")
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response")
                completion(.failure(NSError(domain: "NetworkingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }

            print("HTTP Status Code: \(httpResponse.statusCode)")

            guard let data = data else {
                print("No data received")
                completion(.failure(NSError(domain: "NetworkingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Received response: \(jsonResponse)")
                    completion(.success(jsonResponse))
                } else {
                    print("Invalid JSON response")
                    completion(.failure(NSError(domain: "NetworkingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])))
                }
            } catch {
                print("Error parsing response: \(error)")
                completion(.failure(error))
            }
        }

        task.resume()
    }

    static func sendScreenshot(sessionID: String, lastAction: String, lastActionTimestamp: String, screenshot: NSImage, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let url = backendURL.appendingPathComponent("sessions/\(sessionID)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add screenshot
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"screenshot\"; filename=\"screenshot.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        if let pngData = screenshot.pngData() {
            body.append(pngData)
        }
        body.append("\r\n".data(using: .utf8)!)

        // Add other fields
        let fields = [
            "screenshot_timestamp": ISO8601DateFormatter().string(from: Date()),
            "last_action": lastAction,
            "last_action_timestamp": lastActionTimestamp
        ]

        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error)")
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response")
                completion(.failure(NSError(domain: "NetworkingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }

            print("HTTP Status Code: \(httpResponse.statusCode)")

            guard let data = data else {
                print("No data received")
                completion(.failure(NSError(domain: "NetworkingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received for screenshot"])))
                return
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Received response: \(jsonResponse)")
                    completion(.success(jsonResponse))
                } else {
                    print("Invalid JSON response")
                    completion(.failure(NSError(domain: "NetworkingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response for screenshot"])))
                }
            } catch {
                print("Error parsing response: \(error)")
                completion(.failure(error))
            }
        }

        task.resume()
    }
    
    static func printFrontendInfo(_ frontendInfo: [String: String]) {
        print("Frontend Information:")
        print("---------------------")
        for (key, value) in frontendInfo {
            print("\(key): \(value)")
        }
        print("---------------------")
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}
