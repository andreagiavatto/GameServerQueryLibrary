//
//  SupportedGames.swift
//  SQL
//
//  Created by Andrea on 08/06/2018.
//

import Foundation

public struct MasterServer: CustomStringConvertible {
    public let hostname: String
    public let port: String
    
    public var description: String {
        return "\(hostname):\(port)"
    }
}

public enum SupportedGames: CaseIterable {
    
    case quake3
    case urbanTerror
    
    var name: String {
        switch self {
        case .quake3:
            return "Quake 3 Arena"
        case .urbanTerror:
            return "Urban Terror"
        }
    }
    
    var masterServers: [MasterServer] {
        switch self {
        case .quake3:
            return [MasterServer(hostname: "master.ioquake3.org", port:"27950"),
                    MasterServer(hostname: "master0.excessiveplus.net", port:"27950"),
                    MasterServer(hostname: "master.maverickservers.com", port:"27950"),
                    MasterServer(hostname: "dpmaster.deathmask.net", port:"27950"),
                    MasterServer(hostname: "master.huxxer.de", port:"27950"),
                    MasterServer(hostname: "master.fpsclasico.de", port:"27950"),
                    MasterServer(hostname: "master.quake3arena.com", port:"27950"),]
        case .urbanTerror:
            return [MasterServer(hostname: "master.urbanterror.info", port: "27900"),
                    MasterServer(hostname: "master2.urbanterror.info", port: "27900")]
        }
    }
    
    var coordinator: Coordinator {
        switch self {
        case .quake3:
            return Q3Coordinator()
        case .urbanTerror:
            return Q3Coordinator()
        }
    }
    
    var defaultMasterServer: MasterServer {
        switch self {
        case .quake3:
            return MasterServer(hostname: "dpmaster.deathmask.net", port:"27950")
        case .urbanTerror:
            return MasterServer(hostname: "master.urbanterror.info", port: "27900")
        }
    }

    public var launchArguments: String {
        return "+connect"
    }
}
