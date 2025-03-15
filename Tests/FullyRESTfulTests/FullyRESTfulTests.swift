import XCTest
import Combine

@testable import FullyRESTful
final class TestAPITests: XCTestCase {
    
    func testFetchUserList() async throws {
        let api = TestAPI.ListUsers()
        do {
            let response = try await api.request(param: .init(page: 1))
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
            XCTAssertNotNil(response, "응답이 nil이면 안 됩니다.")
            XCTAssertEqual(response?.name, "John Doe")
            XCTAssertEqual(response?.job, "Developer")
        } catch {
            XCTFail("POST API 호출 실패: \(error.localizedDescription)")
        }
    }
    
    // ✅ PUT 테스트 - 사용자 정보 수정
    func testUpdateUser() async throws {
        let api = TestAPI.UpdateUser(userID: 2)
        do {
            let response = try await api.request(param: .init(name: "Jane Doe", job: "Manager"))
            XCTAssertNotNil(response, "응답이 nil이면 안 됩니다.")
            XCTAssertEqual(response?.name, "Jane Doe")
            XCTAssertEqual(response?.job, "Manager")
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

final class WebSocketTests: XCTestCase {
    var websocketEcho: TestWebSocket.WebSocketEcho!
    var cancellables: Set<AnyCancellable> = []

    override func setUpWithError() throws {
        websocketEcho = TestWebSocket.WebSocketEcho()
    }

    override func tearDownWithError() throws {
        websocketEcho = nil
        cancellables.removeAll()
    }

    /// ✅ 1. WebSocket 연결 테스트 (Echo 서버)
    func testWebSocketEchoConnection() {
        let expectation = expectation(description: "WebSocket (Echo) should connect")
        let topic = websocketEcho.makeTopic(name: "echo")

        topic.listen()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("❌ Echo WebSocket Connection Failed: \(error)")
                }
            }, receiveValue: { message in
                if message != nil {
                    expectation.fulfill()  // ✅ 메시지가 수신되면 성공
                }
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 5.0)
    }

    /// ✅ 2. WebSocket 메시지 송수신 테스트 (Echo 서버)
    func testWebSocketEchoSendAndReceive() async throws {
        let expectation = expectation(description: "WebSocket (Echo) should echo back the message")
        let topic = websocketEcho.makeTopic(name: "echo")
        
        let testMessage = "Hello, Echo WebSocket!"
        
        topic.listen()
            .filter { message in
                // ✅ 서버에서 보내는 다른 메시지는 무시하고 내가 보낸 메시지만 확인
                if case .text(let text) = message {
                    return text == testMessage
                }
                return false
            }
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("❌ Echo WebSocket Echo Failed: \(error)")
                }
            }, receiveValue: { message in
                if case .text(let text) = message {
                    XCTAssertEqual(text, testMessage, "✅ Echo response should match sent message")
                    expectation.fulfill()
                }
            })
            .store(in: &cancellables)
        
        // ✅ 메시지 전송
        let success = try await topic.send(message: .text(testMessage))
        XCTAssertTrue(success, "✅ Echo 메시지 전송 성공")
        
        wait(for: [expectation], timeout: 5.0)
    }

    /// ✅ 3. WebSocket 자동 종료 테스트
    func testWebSocketAutoClose() async throws {
        let topic = websocketEcho.makeTopic(name: "echo")
        let expectation = expectation(description: "WebSocket should close when all subscribers are removed")

        topic.listen()
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        // ✅ 모든 구독을 취소하면 WebSocket이 자동으로 종료되어야 함
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.cancellables.removeAll()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                XCTAssertTrue(self.websocketEcho.publishers.isEmpty, "✅ 모든 구독 취소 후 WebSocket 종료 확인")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
