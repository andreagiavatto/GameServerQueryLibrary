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
    
    private let socketWrapper: SocketWrapper
    
    init?(host: String, port: String) {
        let host = NWEndpoint.Host(host)
        guard let serverPort = UInt16(port), let port = NWEndpoint.Port(rawValue: serverPort) else {
            return nil
        }
        socketWrapper = SocketWrapper(requestMarker: infoRequestMarker, host: host, port: port)
    }
    
    @discardableResult
    func updateInfo(server: Server) async throws -> Server {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.socketWrapper.sendRequest { result in
                switch result {
                case .success(let response):
                    guard let serverInfo = Q3Parser.parseServer(response.data) else {
                        continuation.resume(returning: server)
                        return
                    }
                    server.update(with: serverInfo)
                    continuation.resume(returning: server)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

final class Q3StatusServer {
    private let statusRequestMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x67, 0x65, 0x74, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x0a] // YYYYgetservers 68 empty full
    private let statusResponseMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x0a, 0x5c] // YYYYstatusResponse\n\
    
    private let socketWrapper: SocketWrapper
    
    init?(host: String, port: String) {
        let host = NWEndpoint.Host(host)
        guard let serverPort = UInt16(port), let port = NWEndpoint.Port(rawValue: serverPort) else {
            return nil
        }
        socketWrapper = SocketWrapper(requestMarker: statusRequestMarker, host: host, port: port)
    }
    
    @discardableResult
    func updateStatus(server: Server) async throws -> Server {
        return try await withCheckedThrowingContinuation { continuation in
            socketWrapper.sendRequest { result in
                switch result {
                case .success(let response):
                    guard let serverStatus = Q3Parser.parseServerStatus(response.data) else {
                        continuation.resume(returning: server)
                        return
                    }
                    server.rules = serverStatus.rules
                    server.players = serverStatus.players
                    server.update(currentPlayers: String(serverStatus.players.count), ping: "\(response.runningTime)")
                    continuation.resume(returning: server)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
