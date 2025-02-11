//
//  Q3Server.swift
//  GameServerQueryLibrary
//
//  Created by Andrea G on 20/01/2023.
//

import Foundation
import Network

enum Q3ServerError: Error {
    case invalidPort
    case corruptData
}

final class Q3InfoServer {
    private let infoRequestMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x67, 0x65, 0x74, 0x69, 0x6e, 0x66, 0x6f, 0x0a]
    private let infoResponseMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x69, 0x6e, 0x66, 0x6f, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x0a, 0x5c] // YYYYinfoResponse\n\
    
    private let socketWrapper: AsyncSocketWrapper
    
    init?(host: String, port: String) {
        let host = NWEndpoint.Host(host)
        guard let serverPort = UInt16(port), let port = NWEndpoint.Port(rawValue: serverPort) else {
            return nil
        }
        socketWrapper = AsyncSocketWrapper(requestMarker: infoRequestMarker, host: host, port: port)
    }
    
    @discardableResult
    func updateInfo(server: Server) async throws -> Server {
        let response = try await socketWrapper.sendRequest()
        guard let serverInfo = Q3Parser.parseServer(response.data) else {
            return server
        }
        server.update(with: serverInfo)
        return server
    }
}

final class Q3StatusServer {
    private let statusRequestMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x67, 0x65, 0x74, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x0a] // YYYYgetservers 68 empty full
    private let statusResponseMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x0a, 0x5c] // YYYYstatusResponse\n\
    
    private let socketWrapper: AsyncSocketWrapper
    
    init?(host: String, port: String) {
        let host = NWEndpoint.Host(host)
        guard let serverPort = UInt16(port), let port = NWEndpoint.Port(rawValue: serverPort) else {
            return nil
        }
        socketWrapper = AsyncSocketWrapper(requestMarker: statusRequestMarker, host: host, port: port)
    }
    
    @discardableResult
    func updateStatus(server: Server) async throws -> Server {
        let response = try await socketWrapper.sendRequest()
        guard let serverStatus = Q3Parser.parseServerStatus(response.data) else {
            return server
        }
        server.rules = serverStatus.rules
        server.players = serverStatus.players
        server.update(currentPlayers: String(serverStatus.players.count), map: serverStatus.rules.first(where: { $0.key == "mapname" })?.value, ping: "\(response.runningTime)")
        return server
    }
}
