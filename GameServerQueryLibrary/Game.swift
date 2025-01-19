//
//  Game.swift
//  Q3ServerBrowser
//
//  Created by Andrea Giavatto on 11/16/13.
//
//

import Foundation

public struct Game: Identifiable {
    public let type: SupportedGames
    public let launchArguments: String
    
    public var id: String { name }
    public var name: String { type.name }
    public var coordinator: Coordinator { type.coordinator }
    public var masterServers: [MasterServer] { type.masterServers }
    public var defaultMasterServer: MasterServer { type.defaultMasterServer }

    public init(type: SupportedGames) {
        self.type = type
        self.launchArguments = type.launchArguments
    }
}
