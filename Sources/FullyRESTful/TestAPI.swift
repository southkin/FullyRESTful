//
//  TestAPI.swift
//  FullyRESTful
//
//  Created by kin on 3/14/25.
//

struct TestAPI {
    static let server:ServerInfo = .init(domain: "https://reqres.in", defaultHeader: [:])
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
    }
}
