//
//  Server.swift
//  ServerQueryLibrary
//
//  Created by Andrea Giavatto on 3/19/14.
//
//

import Foundation

@objc public protocol Server: NSCoding {
    
    var ping: String { get }
    var pingInt: Int { get }
    var ip: String { get }
    var port: String { get }
    var originalName: String { get }
    var name: String { get }
    var map: String { get }
    var maxPlayers: String { get }
    var currentPlayers: String { get }
    var mod: String { get }
    var gametype: String { get }
    var rules: [String: String] { get set }
    var players: [Player]? { get set }
    var inGamePlayers: String { get }
    var hostname: String { get }

    init(ip: String, port: String)
    func update(with serverInfo: [String: String]?, ping: String)
    func update(currentPlayers: String, ping: String)
    
}
