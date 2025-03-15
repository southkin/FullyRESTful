//
//  ServerInfo.swift
//  FullyRESTful
//
//  Created by kin on 3/15/25.
//

public struct ServerInfo {
    public enum AfterResolve {
        case retry
        case throwError
        case success
    }
    public typealias StatusCodeValid = (Int) -> AfterResolve
    public var domain: String
    public var statusCodeValid: StatusCodeValid?
    public var defaultHeader: [String: String]
    public init(domain: String, statusCodeValid: StatusCodeValid? = nil, defaultHeader: [String: String]) {
        self.domain = domain
        self.statusCodeValid = statusCodeValid
        self.defaultHeader = defaultHeader
    }
}
