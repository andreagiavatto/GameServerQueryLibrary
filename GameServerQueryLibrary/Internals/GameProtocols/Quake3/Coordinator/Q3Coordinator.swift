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

public final actor Q3Coordinator: Coordinator, Sendable {
    public func getServersList(ip: String, port: String) async throws -> [Server] {
        do {
            guard let q3master = Q3Master(host: ip, port: port) else {
                return []
            }
            return try await q3master.getServers()
        } catch {
            NLog.error(error)
            throw error
        }
    }
    
    public func fetchServersInfo(for servers: [Server]) -> AsyncThrowingStream<Server, Error> {
        return AsyncThrowingStream { continuation in
            // Set onTermination before starting the Task so it is always in
            // place before the stream could possibly be finished or cancelled.
            continuation.onTermination = { @Sendable status in
                NLog.log("Stream terminated with status \(status)")
            }
            // [weak self] prevents a retain cycle: if the coordinator is
            // released before all server queries complete, the Task finishes
            // the stream cleanly rather than keeping the coordinator alive.
            Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                // Previously errors thrown inside a bare Task {} were silently
                // swallowed, leaving the stream open forever. The do-catch
                // ensures the stream is always terminated, success or failure.
                do {
                    try await withThrowingTaskGroup(of: Server.self) { taskGroup in
                        for server in servers {
                            if !taskGroup.isCancelled {
                                taskGroup.addTask {
                                    return try await self.updateServerInfo(server)
                                }
                            }
                        }
                        for try await item in taskGroup {
                            continuation.yield(item)
                        }
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
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
}
