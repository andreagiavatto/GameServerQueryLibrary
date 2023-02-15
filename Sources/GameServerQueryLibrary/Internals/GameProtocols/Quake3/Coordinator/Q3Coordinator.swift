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
    private let q3master = Q3Master()
    private var q3InfoServer: Q3Server?
    private var q3StatusServer: Q3Server?
    private var fetchingServersTask: Task<Void, Never>?
    
    public func getServersList(ip: String, port: String) async {
        do {
            let servers = try await q3master.getServers(ip: ip, port: port)
            await fetchServersInfo(for: servers)
        } catch {
            print(">>> MASTER \(error)")
        }
    }
    
    public func fetchServersInfo(for servers: [Server]) async {
        reset()
        print(">>> Fetched \(servers.count) servers from master server")
        guard !servers.isEmpty else {
            return
        }
        
        fetchingServersTask = Task {
            await withTaskGroup(of: Server?.self, body: { group in
                for server in servers {
                    try? await Task.sleep(for: .milliseconds(100))
                    group.addTask {
                        let q3Server = Q3Server(server: server)
                        let infoServer = try? await q3Server.updateInfo()
                        if infoServer != nil, let updatedServer = try? await q3Server.updateStatus() {
                            self.servers.value.append(updatedServer)
                            return updatedServer
                        }
                        return nil
                    }
                }
            })
        }
    }

    func updateServerInfo(_ server: Server) async -> Server {
        let q3Server = Q3Server(server: server)
        q3InfoServer = q3Server
        do {
            return try await q3Server.updateInfo()
        } catch {
            print(">>> INFO \(error)")
        }
        return server
    }
    
    func updateServerStatus(_ server: Server) async -> Server {
        let q3Server = Q3Server(server: server)
        q3StatusServer = q3Server
        do {
            return try await q3Server.updateStatus()
        } catch {
            print(">>> STATUS \(error)")
        }
        return server
    }
    
    private func reset() {
        fetchingServersTask?.cancel()
        q3InfoServer = nil
        q3StatusServer = nil
        servers.value.removeAll()
    }
}
