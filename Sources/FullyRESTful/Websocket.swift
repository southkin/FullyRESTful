//
//  Websocket.swift
//  FullyRESTful
//
//  Created by kin on 3/15/25.
//

import Combine
import Foundation

/// ✅ WebSocket 전송 메시지 타입
public enum WebSocketSendMessageModel {
    case text(String)
    case codable(Codable)
    case binary(Data)
}

/// ✅ WebSocket 수신 메시지 타입
public enum WebSocketReceiveMessageModel {
    case text(String)
    case binary(Data)
}
public protocol WebSocketAPIITEM_Protocol {
    var server: ServerInfo { get set }
    var path: String { get set }
}
/// ✅ WebSocket API 인터페이스
open class WebSocketAPIITEM_Class {
    public var webSocketTask: URLSessionWebSocketTask?
    public var publishers: [String: CurrentValueSubject<WebSocketReceiveMessageModel?, Error>] = .init()
    public var pingInterval:TimeInterval = 10
    public init() {}
}
public typealias WebSocketAPIITEM = WebSocketAPIITEM_Class & WebSocketAPIITEM_Protocol

public extension WebSocketAPIITEM_Protocol where Self: WebSocketAPIITEM_Class {
    var header: [String: String] { self.server.defaultHeader }
    /// ✅ 새로운 토픽 생성
    func makeTopic(name: String) -> TopicITEM {
        return TopicITEM(topicName: name, id: UUID().uuidString, parentWebsocket: self)
    }
    
    /// ✅ WebSocket 연결 (연결 후 listen 실행)
    func connectIfNeeded() {
        guard webSocketTask == nil else { return }  // ✅ 이미 연결되어 있으면 패스
        
        guard let url = URL(string: server.domain + path) else {
            print("❌ Invalid WebSocket URL")
            return
        }
        
        let request = URLRequest(url: url)
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        print("✅ WebSocket 연결 시작: \(url)")
        
        listenForConnection()
    }
    /// ✅ WebSocket 연결 상태 확인
    private func listenForConnection() {
        DispatchQueue.main.asyncAfter(deadline: .now() + pingInterval) {
            self.webSocketTask?.sendPing { error in
                if let error = error {
                    print("❌ WebSocket Ping Failed: \(error)")
                } else {
                    print("✅ WebSocket 연결 성공")
                    self.listenForConnection()
                }
            }
        }
    }
    /// ✅ 특정 토픽을 구독하여 퍼블리셔 반환 (없으면 생성)
    func getPublisher(requester: TopicITEM) -> AnyPublisher<WebSocketReceiveMessageModel?, Error> {
        connectIfNeeded() // ✅ WebSocket 연결 여부 확인 후 실행
        
        if let publisher = publishers[requester.topicName] {
            return publisher.eraseToAnyPublisher()
        }
        
        let newPublisher = CurrentValueSubject<WebSocketReceiveMessageModel?, Error>(nil)
        publishers[requester.topicName] = newPublisher
        
        listenForMessages(for: requester.topicName, subject: newPublisher)
        return newPublisher
            .handleEvents(receiveCancel: { [weak self] in
                guard let self else { return }
                print("🔴 마지막 구독자가 해제됨: \(requester.topicName), WebSocket 종료")
                self.publishers.removeValue(forKey: requester.topicName)
                
                // ✅ 모든 퍼블리셔가 없으면 WebSocket 자동 종료
                if self.publishers.isEmpty {
                    self.webSocketTask?.cancel(with: .goingAway, reason: nil)
                    self.webSocketTask = nil
                    print("🛑 WebSocket 연결 닫힘 (모든 구독 해제됨)")
                }
            })
            .eraseToAnyPublisher()
    }

    /// ✅ 특정 토픽의 구독 해제 (WebSocket 종료는 자동 처리)
    func close(requester: TopicITEM) {
        publishers.removeValue(forKey: requester.topicName)
    }

    /// ✅ 특정 토픽의 WebSocket 메시지 수신
    private func listenForMessages(for topic: String, subject: CurrentValueSubject<WebSocketReceiveMessageModel?, Error>) {
            webSocketTask?.receive { result in
                switch result {
                case .failure(let error):
                    subject.send(completion: .failure(error))
                case .success(let message):
                    let receivedMessage: WebSocketReceiveMessageModel
                    switch message {
                    case .string(let text):
                        receivedMessage = .text(text)
                    case .data(let data):
                        receivedMessage = .binary(data)
                    @unknown default:
                        return
                    }
                    subject.send(receivedMessage) // ✅ 최신 메시지를 저장

                    // ✅ 재귀 호출로 계속 수신 대기
                    self.listenForMessages(for: topic, subject: subject)
                }
            }
        }

    /// ✅ 특정 채널로 메시지 전송
    func send(_ message: WebSocketSendMessageModel, to channel: String) async throws -> Bool {
        let wsMessage: URLSessionWebSocketTask.Message

        switch message {
        case .text(let text):
            wsMessage = .string(text)
        case .codable(let codable):
            let jsonData = try JSONEncoder().encode(codable)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                wsMessage = .string(jsonString)
            } else {
                throw NSError(domain: "WebSocketError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode Codable to JSON string"])
            }
        case .binary(let data):
            wsMessage = .data(data)
        }

        do {
            try await webSocketTask?.send(wsMessage)
            return true
        } catch {
            return false
        }
    }
    
}

public class TopicITEM {
    let topicName: String
    let id: String
    init(topicName: String, id: String, parentWebsocket: WebSocketAPIITEM) {
        self.topicName = topicName
        self.id = id
        self.parentWebsocket = parentWebsocket
    }
    var parentWebsocket: WebSocketAPIITEM

    /// ✅ 토픽을 구독하여 메시지 수신
    public func listen() -> AnyPublisher<WebSocketReceiveMessageModel?, Error> {
        return parentWebsocket.getPublisher(requester: self)
    }

    /// ✅ 특정 채널로 메시지 전송
    public func send(message: WebSocketSendMessageModel) async throws -> Bool {
        try await parentWebsocket.send(message, to: topicName)
    }

    /// ✅ 토픽 구독 해제
    public func close() {
        parentWebsocket.close(requester: self)
    }
}
