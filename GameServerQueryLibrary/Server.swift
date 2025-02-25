//
//  Server.swift
//  ServerQueryLibrary
//
//  Created by Andrea Giavatto on 3/19/14.
//
//

import Foundation

public class Server: Identifiable, @unchecked Sendable {
    public var id: String { hostname }
    public private(set) var ping: String = ""
    public private(set) var pingInt: Int = 0
    public let ip: String
    public let port: String
    public private(set) var originalName: String = ""
    public private(set) var name: String = ""
    public private(set) var map: String = ""
    public private(set) var maxPlayers: String = ""
    public private(set) var currentPlayers: String = ""
    public private(set) var mod: String = ""
    public private(set) var gametype: String = ""
    public var rules: [Setting] = []
    public var players: [Player] = []
    public private(set) var inGamePlayers: String = "0/0"
    public let hostname: String

    public init(ip: String, port: String) {
        self.ip = ip
        self.port = port
        self.hostname = "\(ip):\(port)"
    }
    
    func update(with serverInfo: [String: String]?) {
        guard let serverInfo = serverInfo, !serverInfo.isEmpty else {
            return
        }
        
        guard
            let originalName = serverInfo["hostname"],
            let map = serverInfo["mapname"],
            let maxPlayers = serverInfo["sv_maxclients"],
            let currentPlayers = serverInfo["clients"],
            let gametype = serverInfo["gametype"]
        else {
            return
        }

        self.originalName = originalName
        self.map = map
        self.maxPlayers = maxPlayers
        self.currentPlayers = currentPlayers
        self.inGamePlayers = "\(self.currentPlayers) / \(self.maxPlayers)"
        self.mod = serverInfo["game"] ?? "baseq3"
        
        if !gametype.isEmpty, let gtype = Int(gametype) {
            switch gtype {
            case 0, 2:
                self.gametype = "ffa"
            case 1:
                self.gametype = "tourney"
            case 3:
                self.gametype = "tdm"
            case 4:
                self.gametype = "ctf"
            default:
                self.gametype = "unknown"
            }
        } else {
            self.gametype = "unknown"
        }
        
        self.name = originalName.q3ColorDecoded
    }
    
    func update(currentPlayers: String, map: String?, ping: String) {
        guard ping.count > 0 else {
            return
        }
        self.ping = ping
        self.pingInt = Int(ping) ?? 0
        self.map = map ?? self.map
        self.currentPlayers = currentPlayers
        self.inGamePlayers = "\(self.currentPlayers) / \(self.maxPlayers)"
    }
}

extension Server: CustomStringConvertible {
    public var description: String {
        "\(name) -- \(hostname) -- \(inGamePlayers) -- \(map)"
    }
}

extension Server: Equatable {
    public static func == (lhs: Server, rhs: Server) -> Bool {
        lhs.id == rhs.id
    }
}

public struct Setting: Identifiable, Sendable {
    public var id: String { key + value }
    public let key: String
    public let value: String
    
    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}
