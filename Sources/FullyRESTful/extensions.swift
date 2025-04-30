//
//  extensions.swift
//  FullyRESTful
//
//  Created by kin on 3/15/25.
//

import KinKit
import Combine

extension URLSession {
    func getData(for request: URLRequest) async throws -> (Data, URLResponse) {
        if #available(iOS 15, *) {
            return try await data(for: request)
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                let task = self.dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if let data = data, let response = response {
                        continuation.resume(returning: (data, response))
                    } else {
                        let error = URLError(.badServerResponse)
                        continuation.resume(throwing: error)
                    }
                }
                task.resume()
            }
        }
    }
}

extension URLRequest {
    var curlString: String {
        guard let url = self.url else { return "" }
        var baseCommand = "curl \"\(url.absoluteString)\""
        if self.httpMethod == "HEAD" {
            baseCommand += " --head"
        }
        var command = [baseCommand]
        if let method = self.httpMethod, method != "GET" && method != "HEAD" {
            command.append("-X \(method)")
        }
        if let headers = self.allHTTPHeaderFields {
            for (header, value) in headers where header != "Content-Type" {
                let escapedHeader = header.replacingOccurrences(of: "\"", with: "\\\"")
                let escapedValue = value.replacingOccurrences(of: "\"", with: "\\\"")
                command.append("-H \"\(escapedHeader): \(escapedValue)\"")
            }
        }
        if let bodyData = self.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
            let escapedBody = bodyString.replacingOccurrences(of: "\"", with: "\\\"")
            command.append("-d \"\(escapedBody)\"")
        }
        return command.joined(separator: " ")
    }
}

extension Dictionary {
    var queryString: String {
        return self.map { (key, value) in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")
    }
}

extension Encodable {
    var dict: [String: Any]? {
        guard let data = self.data else { return nil }
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            return jsonObject as? [String: Any]
        } catch {
            print("Failed to convert Encodable to dictionary: \(error)")
            return nil
        }
    }
    
    var allProperties: [(String, Encodable?)] {
        var result = [(String, Encodable?)]()
        let mirror = Mirror(reflecting: self)
        guard let style = mirror.displayStyle, style == .struct || style == .class else {
            return []
        }
        for (property, value) in mirror.children {
            if let p = property {
                result.append((p, value as? Encodable))
            }
        }
        return result
    }
    
    var JSONString: String? {
        guard let data = self.data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    var data: Data? {
        return try? JSONEncoder().encode(self)
    }
    
    func dataWithThrows() throws -> Data {
        return try JSONEncoder().encode(self)
    }
}
public extension Publisher where Output == WebSocketReceiveMessageModel?, Failure == Never {
    func decode<T: Decodable>(_ type: T.Type) -> AnyPublisher<T, Error> {
        self
            .compactMap { $0 }
            .tryMap { message in
                switch message {
                case .text(let text):
                    guard let data = text.data(using: .utf8) else {
                        throw URLError(.cannotDecodeRawData)
                    }
                    return try JSONDecoder().decode(T.self, from: data)
                case .binary(let data):
                    return try JSONDecoder().decode(T.self, from: data)
                }
            }
            .eraseToAnyPublisher()
    }
}
public extension Publisher where Output == WebSocketReceiveMessageModel, Failure == Never {
    func decode<T: Decodable>(_ type: T.Type) -> AnyPublisher<T, Error> {
        self
            .tryMap { message in
                switch message {
                case .text(let text):
                    guard let data = text.data(using: .utf8) else {
                        throw URLError(.cannotDecodeRawData)
                    }
                    return try JSONDecoder().decode(T.self, from: data)
                case .binary(let data):
                    return try JSONDecoder().decode(T.self, from: data)
                }
            }
            .eraseToAnyPublisher()
    }
}
