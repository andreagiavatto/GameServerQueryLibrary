//
//  Q3Coordinator.swift
//  Q3ServerBrowser
//
//  Created by Andrea Giavatto on 3/7/14.
//
//

import Combine
import Foundation
import AsyncAlgorithms

enum Q3Error: Error {
    case emptyServers
    case infoError(Error)
    case status(Error)
}

public class Q3Coordinator: Coordinator {
    private var fetchingServersTask: Task<Void, Never>?
    
    public func getServersList(ip: String, port: String) async throws -> [Server] {
        do {
            guard let q3master = Q3Master(host: ip, port: port) else {
                return []
            }
            return try await q3master.getServers()
        } catch {
            NLog.log(error)
            throw error
        }
    }
    
    public func fetchServersInfo(for servers: [Server], waitTimeInMilliseconds: TimeInterval = 100) -> AsyncStream<Server> {
        return AsyncStream { continuation in
            fetchingServersTask = Task { [weak self] in
                for server in servers {
                    guard !Task.isCancelled else {
                        continuation.finish()
                        return
                    }
                    do {
                        if let updatedServer = try await self?.updateServerInfo(server) {
                            continuation.yield(updatedServer)
                        }
                    } catch {
                        NLog.error(error)
                    }
                }
                continuation.finish()
            }
        }
    }

    public func updateServerInfo(_ server: Server) async throws -> Server {
        guard let q3InfoServer = Q3InfoServer(host: server.ip, port: server.port) else {
            return server
        }
        do {
            return try await q3InfoServer.updateInfo(server: server)
        } catch {
            NLog.error(error)
            throw error
        }
    }
    
    public func updateServerStatus(_ server: Server) async throws -> Server {
        guard let q3StatusServer = Q3StatusServer(host: server.ip, port: server.port) else {
            return server
        }
        do {
            return try await q3StatusServer.updateStatus(server: server)
        } catch {
            NLog.error(error)
            throw error
        }
    }
    
    private func reset() {
        fetchingServersTask?.cancel()
    }
}
