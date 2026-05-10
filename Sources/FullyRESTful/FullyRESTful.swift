import Foundation
import KinKit

public protocol MultipartUpload {}

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
            throw FullyRESTfulError.parameterEncodingFailed
        }
    }
}

public enum FullyRESTfulError: LocalizedError {
    case badURL(String)
    case invalidResponse
    case parameterEncodingFailed
    case retriesExceeded(Int)
    case httpError(statusCode: Int, data: Data)
    case unsupportedContentType(String?)
    case emptyResponseBody
    case stringResponseMismatch
    case requestBodyEncodingFailed(String)
    case invalidWebSocketState

    public var errorDescription: String? {
        switch self {
        case .badURL(let urlString):
            return "Invalid URL: \(urlString)"
        case .invalidResponse:
            return "Invalid server response"
        case .parameterEncodingFailed:
            return "Failed to encode request parameters"
        case .retriesExceeded(let count):
            return "Maximum retry attempts exceeded: \(count)"
        case .httpError(let statusCode, _):
            return "Server returned status code \(statusCode)"
        case .unsupportedContentType(let contentType):
            return "Unsupported Content-Type: \(contentType ?? "unknown")"
        case .emptyResponseBody:
            return "Response body is empty"
        case .stringResponseMismatch:
            return "ResponseModel is not compatible with string response"
        case .requestBodyEncodingFailed(let key):
            return "Failed to encode multipart parameter \(key)"
        case .invalidWebSocketState:
            return "WebSocket connection is not ready"
        }
    }
}

public struct EmptyResponse: Codable {
    public init() {}
}

public protocol APIITEM_BASE {
    var method: HTTPMethod { get }
    var server: ServerInfo { get }
    var path: String { get }
    var header: [String: String] { get }
    var customHeader: [String: String]? { get set }
    var paramEncoder: ParameterEncode { get }
    var strEncoder: String.Encoding { get }
    var curlLog: Bool { get }
    var session: URLSession { get }
    var retryLimit: Int { get }
    var decoder: JSONDecoder { get }
}

public extension APIITEM_BASE {
    var header: [String: String] {
        if let custom = customHeader {
            return server.defaultHeader.merging(custom) { _, new in new }
        }
        return server.defaultHeader
    }

    var defaultStatusCodeValid: ServerInfo.StatusCodeValid {
        { statusCode in
            (200...299).contains(statusCode) ? .success : .throwError
        }
    }

    var statusCodeValid: ServerInfo.StatusCodeValid {
        server.statusCodeValid ?? defaultStatusCodeValid
    }

    var paramEncoder: ParameterEncode { .JSONEncode }
    var strEncoder: String.Encoding { .utf8 }
    var curlLog: Bool { false }
    var session: URLSession { .shared }
    var retryLimit: Int { 3 }
    var decoder: JSONDecoder { JSONDecoder() }
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

public extension APIITEM {
    func getData(param: RequestModel) async throws -> DataResponse {
        let request = try makeURLRequest(param: param)

        if curlLog {
            print(request.curlString)
        }

        var retries = 0
        while true {
            let (data, response) = try await session.getData(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FullyRESTfulError.invalidResponse
            }

            switch statusCodeValid(httpResponse.statusCode) {
            case .success:
                return .init(data: data, rawResponse: httpResponse)
            case .retry:
                retries += 1
                guard retries <= retryLimit else {
                    throw FullyRESTfulError.retriesExceeded(retryLimit)
                }
            case .throwError:
                throw FullyRESTfulError.httpError(statusCode: httpResponse.statusCode, data: data)
            }
        }
    }

    func request(param: RequestModel) async throws -> APIResponse<ResponseModel> {
        let dataInfo = try await getData(param: param)
        let model = try decodeResponse(dataInfo.data, response: dataInfo.rawResponse)
        return .init(model: model, rawResponse: dataInfo.rawResponse)
    }

    private func makeURLRequest(param: RequestModel) throws -> URLRequest {
        let urlString = "\(server.domain)\(path)"
        guard var url = URL(string: urlString) else {
            throw FullyRESTfulError.badURL(urlString)
        }

        if method == .GET, let dict = param.dict {
            guard var components = URLComponents(string: urlString) else {
                throw FullyRESTfulError.badURL(urlString)
            }
            components.queryItems = dict.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
            guard let builtURL = components.url else {
                throw FullyRESTfulError.badURL(urlString)
            }
            url = builtURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        for (key, value) in header {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if self is MultipartUpload {
            let boundary = generateBoundary()
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            let parameters = Dictionary(uniqueKeysWithValues: param.allProperties.compactMap { key, value in
                value.map { (key, $0) }
            })
            request.httpBody = try createMultipartBody(boundary: boundary, parameters: parameters)
            return request
        }

        if method != .GET {
            request.httpBody = try paramEncoder.encoding(param: param)
        }

        return request
    }

    private func decodeResponse(_ data: Data, response: HTTPURLResponse) throws -> ResponseModel? {
        if data.isEmpty {
            return try decodeEmptyResponse()
        }

        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased()

        if contentType?.contains("application/json") == true || contentType == nil {
            do {
                return try decoder.decode(ResponseModel.self, from: data)
            } catch {
                print("❌ JSON decode failed: \(error)")
                print("📦 Raw Data: \(String(data: data, encoding: .utf8) ?? "N/A")")
                throw error
            }
        }

        if contentType?.contains("text/plain") == true || contentType?.contains("text/") == true {
            guard ResponseModel.self == String.self else {
                throw FullyRESTfulError.stringResponseMismatch
            }
            guard let text = String(data: data, encoding: strEncoder) else {
                throw FullyRESTfulError.stringResponseMismatch
            }
            return text as? ResponseModel
        }

        throw FullyRESTfulError.unsupportedContentType(contentType)
    }

    private func decodeEmptyResponse() throws -> ResponseModel? {
        if ResponseModel.self == EmptyResponse.self {
            return EmptyResponse() as? ResponseModel
        }

        if let decoded = try? decoder.decode(ResponseModel.self, from: Data("{}".utf8)) {
            return decoded
        }

        throw FullyRESTfulError.emptyResponseBody
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
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw FullyRESTfulError.requestBodyEncodingFailed(key)
            }
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n")
            body.append("Content-Type: application/json\r\n\r\n")
            body.append(jsonString)
            body.append("\r\n")
        }
    }

    body.append("--\(boundary)--\r\n")
    return body
}

func generateBoundary() -> String {
    "Boundary-\(UUID().uuidString)"
}

extension Data {
    mutating func append(_ string: String, using encoding: String.Encoding = .utf8) {
        if let data = string.data(using: encoding) {
            append(data)
        }
    }
}
