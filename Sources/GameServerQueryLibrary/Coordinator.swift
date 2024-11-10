//
//  Coordinator.swift
//  SQL
//
//  Created by Andrea on 08/06/2018.
//

import Combine
import Foundation

public protocol Coordinator: Actor {
    func getServersList(ip: String, port: String) async throws -> [Server]
    func fetchServersInfo(for servers: [Server]) -> AsyncThrowingStream<Server, Error>
    func updateServerInfo(_ server: Server) async throws -> Server
    func updateServerStatus(_ server: Server) async throws -> Server
}
