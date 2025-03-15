//
//  TestAPI.swift
//  FullyRESTful
//
//  Created by kin on 3/14/25.
//

import Foundation
import Combine

enum TestAPI {
    static let server:ServerInfo = .init(domain: "https://reqres.in", defaultHeader: ["Content-Type":"application/json"])
}
struct TestUserInfo : Codable {
    let id:Int
    let email:String
    let first_name:String
    let last_name:String
    let avatar:String
}
extension TestAPI {
    struct ListUsers : APIITEM {
        struct Request : Codable {
            let page:Int
        }
        struct SupportInfo: Codable {
            let url:String
            let text:String
        }
        struct Response : Codable {
            let page:Int
            let per_page:Int
            let total:Int
            let total_pages:Int
            let data:[TestUserInfo]
            let support:SupportInfo
        }
        var requestModel = Request.self
        var responseModel = Response.self
        var method: HTTPMethod = .GET
        var server: ServerInfo = TestAPI.server
        var path: String = "/api/users"
        var curlLog = true
    }
    // ✅ POST - 사용자 생성
    struct CreateUser: APIITEM {
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
        
        var requestModel = Request.self
        var responseModel = Response.self
        var method: HTTPMethod = .POST
        var server: ServerInfo = TestAPI.server
        var path: String = "/api/users"
        var curlLog = true
    }
    
    // ✅ PUT - 사용자 정보 수정
    struct UpdateUser: APIITEM {
        struct Request: Codable {
            let name: String
            let job: String
        }
        
        struct Response: Codable {
            let name: String
            let job: String
            let updatedAt: String
        }
        
        var requestModel = Request.self
        var responseModel = Response.self
        var method: HTTPMethod = .PUT
        var server: ServerInfo = TestAPI.server
        var path: String
        var curlLog = true
        init(userID: Int) {
            self.path = "/api/users/\(userID)"
        }
    }
    
    struct DeleteUser: APIITEM {
        struct Request: Codable {}
        
        struct Response: Codable {}
        
        var requestModel = Request.self
        var responseModel = Response.self
        var method: HTTPMethod = .DELETE
        var server: ServerInfo = TestAPI.server
        var path: String
        var curlLog = true
        var header: [String : String] = [:]
        init(userID: Int) {
            self.path = "/api/users/\(userID)"
        }
    }
}

enum TestWebSocket {}
extension TestWebSocket {
    class WebSocketEcho: WebSocketAPIITEM {
        var publishers: [String: CurrentValueSubject<WebSocketReceiveMessageModel?, any Error>] = [:]
        var webSocketTask: URLSessionWebSocketTask?
        var server: ServerInfo = .init(domain: "wss://echo.websocket.org", defaultHeader: [:])
        var path: String = ""
    }
}

