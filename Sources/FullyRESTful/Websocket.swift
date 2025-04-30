//
//  WebSocket.swift
//  FullyRESTful
//
//  Created by kin on 3/15/25.
//

import KinKit
import Combine

// MARK: - 메시지 모델

public enum WebSocketSendMessageModel {
    case text(String)
    case codable(Codable)
    case binary(Data)
}

public enum WebSocketReceiveMessageModel {
    case text(String)
    case binary(Data)
}

// MARK: - WebSocket 엔드포인트 선언용 프로토콜

public protocol WebSocketITEM: Hashable {
    var server: ServerInfo { get }
    var path: String { get }
    var pingInterval: TimeInterval { get }

    var fullURL: URL? { get }
    func listen() -> AnyPublisher<WebSocketReceiveMessageModel, Never>
    func send(_ message: WebSocketSendMessageModel) async throws
}

public extension WebSocketITEM {
    var pingInterval: TimeInterval { 10 }
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

// MARK: - 개별 연결 객체

fileprivate final class WebSocketConnection {
    let url: URL
    private var task: URLSessionWebSocketTask?
    private var subject = PassthroughSubject<WebSocketReceiveMessageModel, Never>()
    private var isConnected = false
    private var pingInterval: TimeInterval

    init(url: URL, pingInterval: TimeInterval) {
        self.url = url
        self.pingInterval = pingInterval
    }

    var publisher: AnyPublisher<WebSocketReceiveMessageModel, Never> {
        subject
            .handleEvents(receiveCancel: { [weak self] in
                self?.handleCancel()
            })
            .eraseToAnyPublisher()
    }

    func connectIfNeeded() {
        guard !isConnected else { return }

        let request = URLRequest(url: url)
        task = URLSession.shared.webSocketTask(with: request)
        task?.resume()
        isConnected = true
        listen()
        ping()
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let error):
                print("❌ WebSocket 수신 실패: \(error)")
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
                subject.send(model)
                self.listen()
            }
        }
    }

    private func ping() {
        DispatchQueue.main.asyncAfter(deadline: .now() + pingInterval) {
            self.task?.sendPing { [weak self] error in
                if error != nil {
                    print("❌ WebSocket 핑 실패")
                } else {
                    self?.ping()
                }
            }
        }
    }

    func send(_ message: WebSocketSendMessageModel) async throws {
        guard let task = task else { return }
        let wsMessage: URLSessionWebSocketTask.Message

        switch message {
        case .text(let text):
            wsMessage = .string(text)
        case .binary(let data):
            wsMessage = .data(data)
        case .codable(let codable):
            let jsonData = try JSONEncoder().encode(codable)
            guard let jsonStr = String(data: jsonData, encoding: .utf8) else {
                throw NSError(domain: "EncodeError", code: -1)
            }
            wsMessage = .string(jsonStr)
        }

        try await task.send(wsMessage)
    }

    private func handleCancel() {
        print("🔴 모든 구독 해제됨 – WebSocket 연결 종료")
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false

        // 연결 해제 시 매니저에서 제거되도록 요청
        WebSocketConnectionManager.shared.removeConnection(for: url)
    }
}

// MARK: - WebSocket 연결 매니저 (싱글톤)

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
            connection.connectIfNeeded()
            return connection.publisher
        } else {
            let connection = WebSocketConnection(url: url, pingInterval: item.pingInterval)
            connections[url] = connection
            connection.connectIfNeeded()
            return connection.publisher
        }
    }
    @MainActor
    func send(_ message: WebSocketSendMessageModel, for item: any WebSocketITEM) async throws {
        guard let url = item.fullURL else { return }

        if let connection = connections[url] {
            try await connection.send(message)
        }
    }

    func removeConnection(for url: URL) {
        lock.lock()
        defer { lock.unlock() }

        connections.removeValue(forKey: url)
    }
}

#if DEBUG
// MARK: - 디버그용 연결 상태 확인

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
