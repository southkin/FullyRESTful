// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation
extension Dictionary {
    var queryString:String {
        return self.map { (key, value) in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")
    }
}
extension Encodable {
    var dict:[String: Any]? {
        guard let data = self.data, let dict = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            return nil
        }
        return dict
    }
    var allProperties:[(String,Encodable?)] {
        var result = [(String,Encodable?)]()
        let mirror = Mirror(reflecting: self)
        guard let style = mirror.displayStyle, style == .struct || style == .class else {
            return []
        }
        for (property, value) in mirror.children {
            if let p = property {
                result.append((p,value as? Encodable))
            }
        }
        return result
    }
    var JSONString:String? {
        guard let data = self.data else {return nil}
        return String(data: data, encoding: .utf8)
    }
    var data:Data? {
        return try? JSONEncoder().encode(self)
    }
    func dataWithThrows() throws -> Data {
        try JSONEncoder().encode(self)
    }
}
public protocol MultipartUpload {
}
public struct MultipartItem : Codable {
    var data:Data
    var mimeType:String
    var fileName:String
}
public enum HTTPMethod:String {
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
    func encoding(param:Encodable) throws -> Data {
        switch self {
        case .JSONEncode:
            return try param.dataWithThrows()
        case .URLEncode:
            if let data = param.dict?.queryString.data {
                return data
            }
            throw NSError()
        }
    }
}
public struct ServerInfo {
    public enum AfterResolve {
        case retry
        case throwError
        case success
    }
    public typealias StatusCodeValid = (Int) -> (AfterResolve)
    public var domain:String
    public var statusCodeValid:StatusCodeValid?
    public var defaultHeader:[String:String]
    public init(domain: String, statusCodeValid: StatusCodeValid? = nil, defaultHeader: [String: String]) {
        self.domain = domain
        self.statusCodeValid = statusCodeValid
        self.defaultHeader = defaultHeader
    }
}
public protocol APIITEM_BASE {
    var method:HTTPMethod {get}
    var server:ServerInfo {get}
    var path:String {get}
    var header:[String:String] {get}
    var paramEncoder:ParameterEncode {get}
    var strEncoder:String.Encoding {get}
}
public extension APIITEM_BASE {
    var header:[String:String] {
        self.server.defaultHeader
    }
    var defaultStatusCodeValid:ServerInfo.StatusCodeValid {
        return {
            (200...299) ~= $0 ? .success : .throwError
        }
    }
    var statusCodeValid:ServerInfo.StatusCodeValid {
        self.server.statusCodeValid ?? defaultStatusCodeValid
    }
    var paramEncoder:ParameterEncode {
        .JSONEncode
    }
    var strEncoder:String.Encoding {
        .utf8
    }
}
public protocol APIITEM : APIITEM_BASE {
    associatedtype ResponseModel : Decodable
    associatedtype RequestModel : Encodable
    var responseModel:ResponseModel.Type {get}
    var requestModel:RequestModel.Type {get}
}
extension APIITEM {
    public func getData(param:RequestModel) async throws -> Data? {
        let url = URL(string: "\(server.domain)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if self is MultipartUpload {
            let boundary = generateBoundary()
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            let parameters = param.allProperties.reduce(into: [String: Encodable]()) { result, pair in
                result[pair.0] = pair.1
            }
            request.httpBody = createMultipartBody(boundary: boundary, parameters: parameters)
        }
        else {
            for (key, value) in header {
                request.setValue(value, forHTTPHeaderField: key)
            }
            request.httpBody = try paramEncoder.encoding(param: param)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        switch self.statusCodeValid(httpResponse.statusCode) {
        case .success:
            return data
        case .retry:
            return try await self.getData(param:param)
        case .throwError:
            throw NSError()
        }
    }
    public func request(param:RequestModel) async throws -> ResponseModel? {
        guard let data = try await getData(param: param) else {return nil}
        return try JSONDecoder().decode(ResponseModel.self, from: data)
    }
}

func createMultipartBody(boundary: String, parameters: [String: Encodable]) -> Data {
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
        case let val as Float:
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(val)")
            body.append("\r\n")
        case let val as Double:
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(val)")
            body.append("\r\n")
        default:
            let jsonData = try? JSONEncoder().encode(value)
            if let jsonData = jsonData {
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n")
                body.append("Content-Type: application/json\r\n\r\n")
                body.append(jsonData)
                body.append("\r\n")
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
        }
    }
}
