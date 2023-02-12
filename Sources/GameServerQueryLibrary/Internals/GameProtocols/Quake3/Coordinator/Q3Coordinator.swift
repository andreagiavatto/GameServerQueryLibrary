//
//  Q3Coordinator.swift
//  Q3ServerBrowser
//
//  Created by Andrea Giavatto on 3/7/14.
//
//

import AsyncAlgorithms
import Combine
import Foundation

enum Q3Error: Error {
    case emptyServers
    case infoError(Error)
    case status(Error)
}

class Q3Coordinator: Coordinator {
    private(set) var servers = CurrentValueSubject<[Server], Never>([])
    private let q3master = Q3Master()
    private var q3InfoServer: Q3Server?
    private var q3StatusServer: Q3Server?
//    private var runningGroup: TaskGroup<<#ChildTaskResult: Sendable#>>?
    
    public func getServersList(ip: String, port: String) async {
        do {
            let servers = try await q3master.getServers(ip: ip, port: port)
            await fetchServersInfo(for: servers)
        } catch {
            print(">>> MASTER \(error)")
        }
    }
    
    public func fetchServersInfo(for servers: [Server]) async {
        clearServers()
        print(">>> Fetched \(servers.count) servers from master server")
        guard !servers.isEmpty else {
            return
        }
        
        await withTaskGroup(of: Server.self, body: { group in
            for server in servers {
                group.addTask {
                    let infoServer = await self.updateServerInfo(server)
                    let statusServer = await self.updateServerStatus(infoServer)
                    return statusServer
                }
            }
            
            for await updatedServer in group {
                self.servers.value.append(updatedServer)
            }
        })
    }

    func updateServerInfo(_ server: Server) async -> Server {
        let q3Server = Q3Server(server: server)
        q3InfoServer = q3Server
        do {
            try await q3Server.updateInfo()
            return q3Server.server
        } catch {
            print(">>> INFO \(error)")
        }
        return server
    }
    
    func updateServerStatus(_ server: Server) async -> Server {
        let q3Server = Q3Server(server: server)
        q3StatusServer = q3Server
        do {
            try await q3Server.updateStatus()
            return q3Server.server
        } catch {
            print(">>> STATUS \(error)")
        }
        return server
    }
    
    private func clearServers() {
        q3InfoServer = nil
        q3StatusServer = nil
        servers.value.removeAll()
    }
}
