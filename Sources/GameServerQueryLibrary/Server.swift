//
//  Server.swift
//  ServerQueryLibrary
//
//  Created by Andrea Giavatto on 3/19/14.
//
//

import Foundation

public final class Server: Identifiable {
    
    private(set) var ping: String?
    private(set) var pingInt: Int?
    private(set) var ip: String
    private(set) var port: String
    private(set) var originalName: String?
    private(set) var name: String?
    private(set) var map: String?
    private(set) var maxPlayers: String?
    private(set) var currentPlayers: String?
    private(set) var mod: String?
    private(set) var gametype: String?
    var rules: [String: String]?
    var players: [Player]?
    private(set) var inGamePlayers: String?
    private(set) var hostname: String?

    required public init(ip: String, port: String) {
        self.ip = ip
        self.port = port
    }
    
    func update(with serverInfo: [String: String]?, ping: String) {
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

        self.ping = ping
        self.pingInt = Int(ping) ?? 0
        self.originalName = originalName
        self.map = map
        self.maxPlayers = maxPlayers
        self.currentPlayers = currentPlayers
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
    
    func update(currentPlayers: String, ping: String) {
        guard ping.count > 0 else {
            return
        }
        self.ping = ping
        self.pingInt = Int(ping) ?? 0
        self.currentPlayers = currentPlayers
    }
    
}
