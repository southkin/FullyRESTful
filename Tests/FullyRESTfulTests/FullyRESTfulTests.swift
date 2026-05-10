import XCTest
import Foundation
import Combine

@testable import FullyRESTful

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            XCTFail("requestHandler is not set")
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class TestAPITests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        session = nil
        super.tearDown()
    }

    private var server: ServerInfo {
        .init(domain: "https://example.com", defaultHeader: ["Content-Type": "application/json"])
    }

    private static func requestBodyString(from request: URLRequest) -> String? {
        if let data = request.httpBody {
            return String(data: data, encoding: .utf8)
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read > 0 {
                data.append(buffer, count: read)
            } else {
                break
            }
        }

        return String(data: data, encoding: .utf8)
    }

    private static func requestBodyJSONObject(from request: URLRequest) throws -> [String: String] {
        let body = try XCTUnwrap(requestBodyString(from: request))
        let data = try XCTUnwrap(body.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: String]
        return try XCTUnwrap(object)
    }

    func testGETBuildsQueryAndDecodesJSON() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.com/users?page=1")
            XCTAssertEqual(request.httpMethod, "GET")

            let data = """
            {"data":[{"id":1,"email":"kin@example.com"}]}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }

        let response = try await ListUsersAPI(session: session, server: server)
            .request(param: .init(page: 1))

        XCTAssertEqual(response.model?.data.first?.id, 1)
        XCTAssertEqual(response.model?.data.first?.email, "kin@example.com")
    }

    func testPOSTSendsBodyAndDecodesJSON() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(
                try Self.requestBodyJSONObject(from: request),
                ["name": "John", "job": "Developer"]
            )

            let data = """
            {"id":"1","name":"John","job":"Developer","createdAt":"now"}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json; charset=utf-8"]
            )!
            return (response, data)
        }

        let response = try await CreateUserAPI(session: session, server: server)
            .request(param: .init(name: "John", job: "Developer"))

        XCTAssertEqual(response.model?.name, "John")
        XCTAssertEqual(response.model?.job, "Developer")
    }

    func testEmptyBodyDecodesEmptyResponse() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 204,
                httpVersion: nil,
                headerFields: [:]
            )!
            return (response, Data())
        }

        let response = try await DeleteUserAPI(session: session, server: server)
            .request(param: .init())

        XCTAssertNotNil(response.model)
    }

    func testHTTPErrorIncludesStatusCode() async {
        MockURLProtocol.requestHandler = { request in
            let data = Data(#"{"message":"unauthorized"}"#.utf8)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }

        do {
            _ = try await ListUsersAPI(session: session, server: server).request(param: .init(page: 1))
            XCTFail("Expected error")
        } catch let error as FullyRESTfulError {
            guard case .httpError(let statusCode, let data) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(statusCode, 401)
            XCTAssertEqual(String(data: data, encoding: .utf8), #"{"message":"unauthorized"}"#)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private struct ListUsersAPI: APIITEM {
        var customHeader: [String : String]?
        let session: URLSession
        let server: ServerInfo
        let responseModel = Response.self
        let requestModel = Request.self
        let method: HTTPMethod = .GET
        let path = "/users"

        struct Request: Codable { let page: Int }
        struct Response: Codable { let data: [User] }
        struct User: Codable {
            let id: Int
            let email: String
        }
    }

    private struct CreateUserAPI: APIITEM {
        var customHeader: [String : String]?
        let session: URLSession
        let server: ServerInfo
        let responseModel = Response.self
        let requestModel = Request.self
        let method: HTTPMethod = .POST
        let path = "/users"

        struct Request: Codable {
            let name: String
            let job: String
        }

        struct Response: Codable {
            let id: String
            let name: String
            let job: String
            let createdAt: String
        }
    }

    private struct DeleteUserAPI: APIITEM {
        var customHeader: [String : String]?
        let session: URLSession
        let server: ServerInfo
        let responseModel = EmptyResponse.self
        let requestModel = Request.self
        let method: HTTPMethod = .DELETE
        let path = "/users/1"

        struct Request: Codable {}
    }
}

final class WebSocketTests: XCTestCase {
    private final class MockWebSocketTask: WebSocketTasking {
        var sentMessages: [URLSessionWebSocketTask.Message] = []
        var cancelCalled = false
        var receiveHandler: ((Result<URLSessionWebSocketTask.Message, Error>) -> Void)?

        func resume() {}

        func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
            cancelCalled = true
        }

        func send(_ message: URLSessionWebSocketTask.Message) async throws {
            sentMessages.append(message)
        }

        func receive(completionHandler: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {
            receiveHandler = completionHandler
        }

        func sendPing(completionHandler: @escaping (Error?) -> Void) {
            completionHandler(nil)
        }

        func emit(_ message: URLSessionWebSocketTask.Message) {
            receiveHandler?(.success(message))
        }
    }

    private struct MockWebSocketSession: WebSocketSessioning {
        let task: MockWebSocketTask

        func webSocketTask(with request: URLRequest) -> WebSocketTasking {
            task
        }
    }

    private struct TestSocket: WebSocketITEM {
        var server: ServerInfo
        var path: String
        var webSocketSession: WebSocketSessioning
        var pingInterval: TimeInterval = 60
    }

    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testSendCreatesConnectionAndForwardsMessage() async throws {
        let task = MockWebSocketTask()
        let socket = TestSocket(
            server: .init(domain: "wss://example.com", defaultHeader: [:]),
            path: "/chat",
            webSocketSession: MockWebSocketSession(task: task)
        )

        try await socket.send(.text("hello"))

        guard case .string("hello")? = task.sentMessages.first else {
            return XCTFail("Expected text message")
        }
    }

    func testListenPublishesIncomingMessage() {
        let task = MockWebSocketTask()
        let socket = TestSocket(
            server: .init(domain: "wss://example.com", defaultHeader: [:]),
            path: "/stream",
            webSocketSession: MockWebSocketSession(task: task)
        )

        let expectation = expectation(description: "receive message")
        socket.listen()
            .sink { message in
                guard case .text("hello") = message else {
                    return XCTFail("Unexpected message")
                }
                expectation.fulfill()
            }
            .store(in: &cancellables)

        task.emit(.string("hello"))
        wait(for: [expectation], timeout: 1.0)
    }

    func testCancelDisconnectsConnection() {
        let task = MockWebSocketTask()
        let socket = TestSocket(
            server: .init(domain: "wss://example.com", defaultHeader: [:]),
            path: "/disconnect",
            webSocketSession: MockWebSocketSession(task: task)
        )

        var localCancellable: AnyCancellable? = socket.listen().sink { _ in }
        localCancellable?.cancel()
        localCancellable = nil

        XCTAssertTrue(task.cancelCalled)
        XCTAssertTrue(socket.isDisconnected(socket))
    }
}
