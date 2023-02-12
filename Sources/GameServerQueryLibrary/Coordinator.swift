//
//  Coordinator.swift
//  SQL
//
//  Created by Andrea on 08/06/2018.
//

import Combine
import Foundation

public protocol Coordinator {
    var servers: CurrentValueSubject<[Server], Never> { get }
    
    func getServersList(ip: String, port: String) async
    func fetchServersInfo(for servers: [Server]) async
    func updateServerInfo(_ server: Server) async -> Server
    func updateServerStatus(_ server: Server) async -> Server
}
