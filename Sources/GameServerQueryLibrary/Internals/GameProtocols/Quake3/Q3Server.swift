//
//  Q3Server.swift
//  GameServerQueryLibrary
//
//  Created by Andrea G on 20/01/2023.
//

import Foundation

enum Q3ServerError: Error {
    case invalidPort
    case corruptData
}

actor Q3Server {
    
    private let infoRequestMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x67, 0x65, 0x74, 0x69, 0x6e, 0x66, 0x6f, 0x0a]
    private let infoResponseMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x69, 0x6e, 0x66, 0x6f, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x0a, 0x5c] // YYYYinfoResponse\n\
    
    private let statusRequestMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x67, 0x65, 0x74, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x0a] // YYYYgetservers 68 empty full
    private let statusResponseMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x0a, 0x5c] // YYYYstatusResponse\n\
    
    private let infoSocketWrapper = AsyncSocketWrapper(timeout: 1)
    private let statusSocketWrapper = AsyncSocketWrapper(timeout: 1)
    
    private(set) var server: Server
    
    init(server: Server) {
        self.server = server
    }
    
    func updateInfo() async throws -> Server {
        let ip = server.ip
        guard !ip.isEmpty, let port = UInt16(server.port) else {
            return server
        }
        let response = try await infoSocketWrapper.sendRequest(ip: ip, port: port, requestMarker: infoRequestMarker, responseMarker: infoResponseMarker, eotMarker: nil)
        guard let serverInfo = Q3Parser.parseServer(response.data) else {
            return server
        }
        server.update(with: serverInfo)
        return server
    }
    
    func updateStatus() async throws -> Server {
        let ip = server.ip
        guard !ip.isEmpty, let port = UInt16(server.port) else {
            return server
        }
        let response = try await statusSocketWrapper.sendRequest(ip: ip, port: port, requestMarker: statusRequestMarker, responseMarker: statusResponseMarker, eotMarker: nil)
        guard let serverStatus = Q3Parser.parseServerStatus(response.data) else {
            return server
        }
        self.server.rules = serverStatus.rules
        self.server.players = serverStatus.players.sorted { (first, second) -> Bool in
            guard let firstScore = Int(first.score), let secondScore = Int(second.score) else {
                return false
            }
            return firstScore > secondScore
        }
        server.update(currentPlayers: String(serverStatus.players.count), ping: "\(response.runningTime)")
        return server
    }
}
