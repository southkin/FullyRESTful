import Foundation

public protocol MultipartUpload {
}

public struct MultipartItem: Codable {
    public var data: Data
    public var mimeType: String
    public var fileName: String
    public init(data: Data, mimeType: String, fileName: String) {
        self.data = data
        self.mimeType = mimeType
        self.fileName = fileName
    }
}

public enum HTTPMethod: String, CaseIterable {
    case CONNECT
    case DELETE
    case GET
    case HEAD
    case OPTIONS
    case PATCH
    case POST
    case PUT
    case TRACE
}

public enum ParameterEncode {
    case JSONEncode
    case URLEncode
    func encoding(param: Encodable) throws -> Data {
        switch self {
        case .JSONEncode:
            return try param.dataWithThrows()
        case .URLEncode:
            if let data = param.dict?.queryString.data(using: .utf8) {
                return data
            }
            throw NSError(domain: "ParameterEncode", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode parameters"])
        }
    }
}



public protocol APIITEM_BASE {
    var method: HTTPMethod { get }
    var server: ServerInfo { get }
    var path: String { get }
    var header: [String: String] { get set }
    var paramEncoder: ParameterEncode { get }
    var strEncoder: String.Encoding { get }
    var curlLog: Bool { get }
}
public extension APIITEM_BASE {
    var header: [String: String] {
        self.server.defaultHeader
    }
    var defaultStatusCodeValid: ServerInfo.StatusCodeValid {
        return { statusCode in
            return (200...299).contains(statusCode) ? .success : .throwError
        }
    }
    var statusCodeValid: ServerInfo.StatusCodeValid {
        self.server.statusCodeValid ?? defaultStatusCodeValid
    }
    var paramEncoder: ParameterEncode {
        .JSONEncode
    }
    var strEncoder: String.Encoding {
        .utf8
    }
    var curlLog: Bool {
        false
    }
}

public struct DataResponse {
    public let data: Data
    public let rawResponse: HTTPURLResponse
}
public struct APIResponse<T: Decodable> {
    public let model: T?
    public let rawResponse: HTTPURLResponse
}
public protocol APIITEM: APIITEM_BASE {
    associatedtype ResponseModel: Decodable
    associatedtype RequestModel: Encodable
    var responseModel: ResponseModel.Type { get }
    var requestModel: RequestModel.Type { get }
}

extension APIITEM {
    public func getData(param: RequestModel) async throws -> DataResponse? {
        guard let url = URL(string: "\(server.domain)\(path)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        if self is MultipartUpload {
            let boundary = generateBoundary()
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            let parameters = param.allProperties.reduce(into: [String: Encodable]()) { result, pair in
                result[pair.0] = pair.1
            }
            request.httpBody = try createMultipartBody(boundary: boundary, parameters: parameters)
        } else {
            for (key, value) in header {
                request.setValue(value, forHTTPHeaderField: key)
            }
            if ![HTTPMethod.GET, HTTPMethod.HEAD].contains(method) {
                request.httpBody = try paramEncoder.encoding(param: param)
            }
        }
        
        if curlLog {
            print(request.curlString)
        }
        
        var retries = 0
        let maxRetries = 3
        while retries <= maxRetries {
            let (data, response) = try await URLSession.shared.getData(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            switch self.statusCodeValid(httpResponse.statusCode) {
            case .success:
                return .init(data: data, rawResponse: httpResponse)
            case .retry:
                retries += 1
                continue
            case .throwError:
                let error = NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
                throw error
            }
        }
        throw NSError(domain: "RetriesExceeded", code: -1, userInfo: [NSLocalizedDescriptionKey: "Maximum retry attempts exceeded"])
    }
    
    public func request(param: RequestModel) async throws -> APIResponse<ResponseModel>? {
        guard let dataInfo = try await getData(param: param),
              let contentType = dataInfo.rawResponse.allHeaderFields["Content-Type"] as? String
        else { return nil }
        let response = dataInfo.rawResponse
        let data = dataInfo.data
        
        
        if contentType.contains("application/json") {
            return .init(model: try JSONDecoder().decode(ResponseModel.self, from: data), rawResponse: response)
        } else if contentType.contains("text/plain") {
            return .init(model: String(data: data, encoding: .utf8) as? ResponseModel, rawResponse: response)
        } else {
            return nil
        }
    }
}

func createMultipartBody(boundary: String, parameters: [String: Encodable]) throws -> Data {
    var body = Data()
    
    for (key, value) in parameters {
        body.append("--\(boundary)\r\n")
        switch value {
        case let multipartItem as MultipartItem:
            body.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(multipartItem.fileName)\"\r\n")
            body.append("Content-Type: \(multipartItem.mimeType)\r\n\r\n")
            body.append(multipartItem.data)
            body.append("\r\n")
        case let val as String:
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append(val)
            body.append("\r\n")
        case let val as Int:
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(val)")
            body.append("\r\n")
        case let val as Double:
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(val)")
            body.append("\r\n")
        default:
            let jsonData = try JSONEncoder().encode(value)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n")
                body.append("Content-Type: application/json\r\n\r\n")
                body.append(jsonString)
                body.append("\r\n")
            } else {
                throw NSError(domain: "MultipartBody", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode parameter \(key)"])
            }
        }
    }
    body.append("--\(boundary)--\r\n")
    return body
}

func generateBoundary() -> String {
    return "Boundary-\(UUID().uuidString)"
}

extension Data {
    mutating func append(_ string: String, using encoding: String.Encoding = .utf8) {
        if let data = string.data(using: encoding) {
            append(data)
        } else {
            print("Failed to encode string: \(string)")
        }
    }
}



