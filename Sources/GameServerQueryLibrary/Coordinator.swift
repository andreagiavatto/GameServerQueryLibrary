//
//  Coordinator.swift
//  SQL
//
//  Created by Andrea on 08/06/2018.
//

import Combine
import Foundation

public protocol Coordinator {
    func getServersList(ip: String, port: String) async throws -> [Server]
    func fetchServersInfo(for servers: [Server], waitTimeInMilliseconds: TimeInterval) -> AsyncStream<Server>
    func updateServerInfo(_ server: Server) async throws -> Server
    func updateServerStatus(_ server: Server) async throws -> Server
}
