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
    var websocketEcho: TestWebSocket.WebSocketEcho?
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
        let topic = websocketEcho?.makeTopic(name: "echo")

        topic?.listen()
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            Task {
                let testMessage = "Hello, Echo WebSocket!"
                _ = try await topic?.send(message: .text(testMessage))
            }
        }
        wait(for: [expectation], timeout: 6.0)
    }

    /// ✅ 2. WebSocket 메시지 송수신 테스트 (Echo 서버)
    func testWebSocketEchoSendAndReceive() async throws {
        let expectation = expectation(description: "WebSocket (Echo) should echo back the message")
        let topic = websocketEcho?.makeTopic(name: "echo")
        
        let testMessage = "Hello, Echo WebSocket!"
        
        topic?.listen()
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
        
        _ = try? await topic?.send(message: .text(testMessage))
        await fulfillment(of: [expectation], timeout: 6.0)
    }

    /// ✅ 3. WebSocket 자동 종료 테스트
    func testWebSocketAutoClose() async throws {
        guard let websocketEcho = websocketEcho else {
            XCTFail("❌ WebSocket 인스턴스가 nil 입니다.")
            return
        }

        let topic = websocketEcho.makeTopic(name: "echo")
        let expectation = expectation(description: "WebSocket should close when all subscribers are removed")

        topic.listen()
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
        
        _ = try? await topic.send(message: .text("test"))
        self.checkWebSocketClosed(expectation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.cancellables.removeAll()
        }

        await fulfillment(of: [expectation], timeout: 10.0)
    }

    /// ✅ WebSocket이 닫혔는지 확인하는 함수
    private func checkWebSocketClosed(_ expectation: XCTestExpectation) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [weak self] in
            if self?.websocketEcho?.publishers.isEmpty ?? false {
                print("✅ WebSocket이 정상적으로 종료됨")
                expectation.fulfill()
            } else {
                print("❌ WebSocket 종료 실패, 다시 확인")
                self?.checkWebSocketClosed(expectation) // ✅ 종료될 때까지 반복 체크
            }
        }
    }
}
