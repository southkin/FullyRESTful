import XCTest
import Combine

@testable import FullyRESTful
final class TestAPITests: XCTestCase {
    
    func testFetchUserList() async throws {
        let api = TestAPI.ListUsers()
        do {
            let response = try await api.request(param: .init(page: 1))?.model
            XCTAssertNotNil(response, "응답이 nil이면 안됩니다.")
            XCTAssertGreaterThan(response!.data.count, 0, "유저 목록이 비어 있습니다.")
            
            if let firstUser = response?.data.first {
                XCTAssertNotNil(firstUser.id, "ID 값이 없습니다.")
                XCTAssertNotNil(firstUser.email, "이메일 값이 없습니다.")
            }
        } catch {
            XCTFail("API 호출 실패: \(error.localizedDescription)")
        }
    }
    // ✅ POST 테스트 - 사용자 생성
    func testCreateUser() async throws {
        let api = TestAPI.CreateUser()
        do {
            let response = try await api.request(param: .init(name: "John Doe", job: "Developer"))
            XCTAssertNotNil(response?.model, "응답이 nil이면 안 됩니다.")
            XCTAssertEqual(response?.model?.name, "John Doe")
            XCTAssertEqual(response?.model?.job, "Developer")
        } catch {
            XCTFail("POST API 호출 실패: \(error.localizedDescription)")
        }
    }
    
    // ✅ PUT 테스트 - 사용자 정보 수정
    func testUpdateUser() async throws {
        let api = TestAPI.UpdateUser(userID: 2)
        do {
            let response = try await api.request(param: .init(name: "Jane Doe", job: "Manager"))
            XCTAssertNotNil(response?.model, "응답이 nil이면 안 됩니다.")
            XCTAssertEqual(response?.model?.name, "Jane Doe")
            XCTAssertEqual(response?.model?.job, "Manager")
        } catch {
            XCTFail("PUT API 호출 실패: \(error.localizedDescription)")
        }
    }
    
    // ✅ DELETE 테스트 - 사용자 삭제
    func testDeleteUser() async throws {
        let api = TestAPI.DeleteUser(userID: 2)
        do {
            _ = try await api.request(param: .init())
        } catch {
            XCTFail("DELETE API 호출 실패: \(error.localizedDescription)")
        }
    }
    
}

@testable import FullyRESTful  // ✅ 패키지 이름에 맞게 변경해야 함
@MainActor
final class WebSocketTests: XCTestCase {
    var cancellables: Set<AnyCancellable> = []

    // ✅ Echo 테스트용 WebSocketITEM 정의
    struct EchoSocket: WebSocketITEM {
        var server: ServerInfo = .init(domain: "wss://echo.websocket.org", defaultHeader: [:]) // 실제 작동 주소로 교체
        var path: String = ""
    }

    /// ✅ 1. WebSocket 연결 테스트
    func testWebSocketConnection() {
        let item = EchoSocket()
        let expectation = expectation(description: "WebSocket 연결 후 메시지 수신")

        item.listen()
            .compactMap { $0 }
            .first()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            Task {
                try await item.send(.text("ping"))
//                try? await WebSocketManager.shared.send(.text("ping"), for: item)
            }
        }

        wait(for: [expectation], timeout: 6.0)
    }

    /// ✅ 2. Echo 송수신 테스트
    func testWebSocketEchoSendReceive() async throws {
        let item = EchoSocket()
        let expectation = expectation(description: "보낸 메시지와 같은 메시지를 수신해야 함")
        let testMessage = "Hello, Echo!"

        item.listen()
            .compactMap {
                if case let .text(text) = $0, text == testMessage {
                    return text
                }
                return nil
            }
            .sink { received in
                XCTAssertEqual(received, testMessage)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        try await item.send(.text(testMessage))
//        try await WebSocketManager.shared.send(.text(testMessage), for: item)
        await fulfillment(of: [expectation], timeout: 6.0)
    }

    /// ✅ 3. 자동 연결 종료 테스트
    func testWebSocketAutoDisconnect() async throws {
        let item = EchoSocket()
        let expectation = expectation(description: "구독자가 모두 제거되면 연결이 종료되어야 함")
        
        // 1. 리슨 시작
        var cancellables: Set<AnyCancellable> = []
        item.listen()
            .sink { _ in }
            .store(in: &cancellables)
        
        // 2. 임시 메시지 전송 (연결 활성화 유도)
        try await item.send(.text("temporary"))
        
        // 3. 약간의 딜레이 후 구독 해제
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            cancellables.removeAll()
        }
        
        // 4. 연결이 종료됐는지 확인
        DispatchQueue.global().asyncAfter(deadline: .now() + 4) {
            if item.isDisconnected(item) {
                print("✅ WebSocket 연결 정상 종료됨")
                expectation.fulfill()
            } else {
                XCTFail("❌ WebSocket 연결이 종료되지 않았음")
            }
        }
        
        await fulfillment(of: [expectation], timeout: 8.0)
    }
}
