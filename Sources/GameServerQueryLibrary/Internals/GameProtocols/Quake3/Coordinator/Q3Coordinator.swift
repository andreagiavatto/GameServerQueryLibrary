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

class Q3Coordinator: Coordinator {
    private(set) var servers = CurrentValueSubject<[Server], Never>([])
    private var fetchingServersTask: Task<Void, Never>?
    
    public func getServersList(ip: String, port: String) async {
        do {
            guard let q3master = Q3Master(host: ip, port: port) else {
                return
            }
            let servers = try await q3master.getServers()
            NLog.log("Fetched \(servers.count) servers")
            await fetchServersInfo(for: servers)
        } catch {
            NLog.log(error)
        }
    }
    
    public func fetchServersInfo(for servers: [Server]) async {
        reset()
        guard !servers.isEmpty else {
            return
        }
                
        fetchingServersTask = Task {
            guard !Task.isCancelled else {
                return
            }
            await withTaskGroup(of: Server?.self, body: { [weak self] group in
                guard let self, !Task.isCancelled else {
                    return
                }
                for enumeration in servers.enumerated() {
                    try? await Task.sleep(for: .milliseconds(200))
                    group.addTask {
                        guard !Task.isCancelled else {
                            return nil
                        }
                        let infoServer = await self.updateServerInfo(enumeration.element)
                        let statusServer = await self.updateServerStatus(infoServer)
                        self.servers.value.append(statusServer)
                        return statusServer
                    }
                }
            })
        }
    }

    func updateServerInfo(_ server: Server) async -> Server {
        guard let q3InfoServer = Q3InfoServer(host: server.ip, port: server.port) else {
            return server
        }
        do {
            NLog.log("INFO: \(server.hostname)")
            return try await q3InfoServer.updateInfo(server: server)
        } catch {
            NLog.log(error)
        }
        return server
    }
    
    func updateServerStatus(_ server: Server) async -> Server {
        guard let q3StatusServer = Q3StatusServer(host: server.ip, port: server.port) else {
            return server
        }
        do {
            NLog.log("STATUS: \(server.hostname)")
            return try await q3StatusServer.updateStatus(server: server)
        } catch {
            NLog.log(error)
        }
        return server
    }
    
    private func reset() {
        fetchingServersTask?.cancel()
        servers.value.removeAll()
    }
}
