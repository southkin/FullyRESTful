import Foundation
import KinKit
import Combine

public enum WebSocketSendMessageModel {
    case text(String)
    case codable(Codable)
    case binary(Data)
}

public enum WebSocketReceiveMessageModel {
    case text(String)
    case binary(Data)
}

public protocol WebSocketTasking: AnyObject {
    func resume()
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive(completionHandler: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void)
    func sendPing(completionHandler: @escaping (Error?) -> Void)
}

public protocol WebSocketSessioning {
    func webSocketTask(with request: URLRequest) -> WebSocketTasking
}

public struct URLSessionWebSocketSession: WebSocketSessioning {
    public static let shared = URLSessionWebSocketSession()

    public init() {}

    public func webSocketTask(with request: URLRequest) -> WebSocketTasking {
        URLSessionWebSocketTaskBox(task: URLSession.shared.webSocketTask(with: request))
    }
}

private final class URLSessionWebSocketTaskBox: WebSocketTasking {
    private let task: URLSessionWebSocketTask

    init(task: URLSessionWebSocketTask) {
        self.task = task
    }

    func resume() {
        task.resume()
    }

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        task.cancel(with: closeCode, reason: reason)
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        try await task.send(message)
    }

    func receive(completionHandler: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {
        task.receive(completionHandler: completionHandler)
    }

    func sendPing(completionHandler: @escaping (Error?) -> Void) {
        task.sendPing(pongReceiveHandler: completionHandler)
    }
}

public protocol WebSocketITEM: Hashable {
    var server: ServerInfo { get }
    var path: String { get }
    var pingInterval: TimeInterval { get }
    var webSocketSession: WebSocketSessioning { get }

    var fullURL: URL? { get }
    func listen() -> AnyPublisher<WebSocketReceiveMessageModel, Never>
    func send(_ message: WebSocketSendMessageModel) async throws
}

public extension WebSocketITEM {
    var pingInterval: TimeInterval { 10 }
    var webSocketSession: WebSocketSessioning { URLSessionWebSocketSession.shared }

    var fullURL: URL? {
        URL(string: server.domain + path)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(server.domain)
        hasher.combine(path)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.server.domain == rhs.server.domain && lhs.path == rhs.path
    }

    func listen() -> AnyPublisher<WebSocketReceiveMessageModel, Never> {
        WebSocketConnectionManager.shared.publisher(for: self)
    }

    func send(_ message: WebSocketSendMessageModel) async throws {
        try await WebSocketConnectionManager.shared.send(message, for: self)
    }
}

fileprivate final class WebSocketConnection {
    let url: URL

    private let lock = NSLock()
    private let pingInterval: TimeInterval
    private let session: WebSocketSessioning
    private var task: WebSocketTasking?
    private let subject = PassthroughSubject<WebSocketReceiveMessageModel, Never>()
    private var isConnected = false
    private var subscriberCount = 0

    init(url: URL, pingInterval: TimeInterval, session: WebSocketSessioning) {
        self.url = url
        self.pingInterval = pingInterval
        self.session = session
    }

    func publisher() -> AnyPublisher<WebSocketReceiveMessageModel, Never> {
        Deferred { [weak self] () -> AnyPublisher<WebSocketReceiveMessageModel, Never> in
            guard let self else {
                return Empty().eraseToAnyPublisher()
            }

            self.addSubscriber()
            self.connectIfNeeded()

            return self.subject
                .handleEvents(receiveCancel: { [weak self] in
                    self?.removeSubscriber()
                })
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func send(_ message: WebSocketSendMessageModel) async throws {
        connectIfNeeded()

        guard let task = currentTask else {
            throw FullyRESTfulError.invalidWebSocketState
        }

        let wsMessage: URLSessionWebSocketTask.Message
        switch message {
        case .text(let text):
            wsMessage = .string(text)
        case .binary(let data):
            wsMessage = .data(data)
        case .codable(let codable):
            let jsonData = try JSONEncoder().encode(codable)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw FullyRESTfulError.stringResponseMismatch
            }
            wsMessage = .string(jsonString)
        }

        try await task.send(wsMessage)
    }

    func connectIfNeeded() {
        lock.lock()
        defer { lock.unlock() }

        guard !isConnected else { return }

        let request = URLRequest(url: url)
        let task = session.webSocketTask(with: request)
        self.task = task
        isConnected = true
        task.resume()
        listen(on: task)
        ping(on: task)
    }

    private var currentTask: WebSocketTasking? {
        lock.lock()
        defer { lock.unlock() }
        return task
    }

    private func listen(on task: WebSocketTasking) {
        task.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let error):
                self.disconnect(notifyManager: true)
                print("❌ WebSocket receive failed: \(error)")
            case .success(let message):
                let model: WebSocketReceiveMessageModel
                switch message {
                case .string(let text):
                    model = .text(text)
                case .data(let data):
                    model = .binary(data)
                @unknown default:
                    return
                }

                self.subject.send(model)
                if self.currentTask != nil {
                    self.listen(on: task)
                }
            }
        }
    }

    private func ping(on task: WebSocketTasking) {
        DispatchQueue.global().asyncAfter(deadline: .now() + pingInterval) { [weak self] in
            guard let self else { return }
            guard self.currentTask != nil else { return }

            task.sendPing { [weak self] error in
                guard let self else { return }
                if let error {
                    self.disconnect(notifyManager: true)
                    print("❌ WebSocket ping failed: \(error)")
                } else if self.currentTask != nil {
                    self.ping(on: task)
                }
            }
        }
    }

    private func addSubscriber() {
        lock.lock()
        subscriberCount += 1
        lock.unlock()
    }

    private func removeSubscriber() {
        lock.lock()
        subscriberCount = max(subscriberCount - 1, 0)
        let shouldDisconnect = subscriberCount == 0
        lock.unlock()

        if shouldDisconnect {
            disconnect(notifyManager: true)
        }
    }

    private func disconnect(notifyManager: Bool) {
        lock.lock()
        let task = self.task
        self.task = nil
        isConnected = false
        lock.unlock()

        task?.cancel(with: .goingAway, reason: nil)

        if notifyManager {
            WebSocketConnectionManager.shared.removeConnection(for: url)
        }
    }
}

final class WebSocketConnectionManager {
    static let shared = WebSocketConnectionManager()

    fileprivate var connections: [URL: WebSocketConnection] = [:]
    private let lock = NSLock()

    private init() {}

    func publisher(for item: any WebSocketITEM) -> AnyPublisher<WebSocketReceiveMessageModel, Never> {
        guard let url = item.fullURL else {
            return Empty().eraseToAnyPublisher()
        }

        lock.lock()
        defer { lock.unlock() }

        if let connection = connections[url] {
            return connection.publisher()
        }

        let connection = WebSocketConnection(url: url, pingInterval: item.pingInterval, session: item.webSocketSession)
        connections[url] = connection
        return connection.publisher()
    }

    func send(_ message: WebSocketSendMessageModel, for item: any WebSocketITEM) async throws {
        guard let url = item.fullURL else {
            throw FullyRESTfulError.invalidWebSocketState
        }

        let connection = connection(for: url, pingInterval: item.pingInterval, session: item.webSocketSession)
        try await connection.send(message)
    }

    func removeConnection(for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        connections.removeValue(forKey: url)
    }

    private func connection(for url: URL, pingInterval: TimeInterval, session: WebSocketSessioning) -> WebSocketConnection {
        lock.lock()
        defer { lock.unlock() }

        if let existing = connections[url] {
            return existing
        }

        let created = WebSocketConnection(url: url, pingInterval: pingInterval, session: session)
        connections[url] = created
        return created
    }
}

#if DEBUG
public extension WebSocketITEM {
    func isDisconnected(_ item: any WebSocketITEM) -> Bool {
        WebSocketConnectionManager.shared.isDisconnected(self)
    }
}

extension WebSocketConnectionManager {
    func isDisconnected(_ item: any WebSocketITEM) -> Bool {
        guard let url = item.fullURL else { return true }
        return connections[url] == nil
    }
}
#endif
