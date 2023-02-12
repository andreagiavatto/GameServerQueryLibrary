//
//  Server+Teams.swift
//  Q3ServerBrowser
//
//  Created by HLR on 13/12/2019.
//

import Foundation

public enum TeamType: String {
    case spectators
    case red
    case blue
}

public struct Team {
    public let type: TeamType
    public let score: String
    public let players: [Player]
}

public extension Server {
    
    var hasPlayers: Bool {
        return !players.isEmpty
    }
    
    var isATeamMode: Bool {
        return gametype == "ctf" || gametype == "tdm"
    }
    
    var teamSpectator: Team? {
        guard isATeamMode else {
            return nil
        }
        var spectators = [Player]()
        guard let playersInRedTeam = redPlayersInRules?.components(separatedBy: " ") else {
            return Team(type: .spectators, score: "", players: spectators)
        }
        guard let playersInBlueTeam = bluePlayersInRules?.components(separatedBy: " ") else {
            return Team(type: .spectators, score: "", players: spectators)
        }
        let allPlayingPlayers = playersInBlueTeam + playersInRedTeam
        spectators = players.enumerated().filter { (index, _) -> Bool in
            !allPlayingPlayers.contains("\(index + 1)")
        }.map { $1 }
        return Team(type: .spectators, score: "", players: spectators)
    }
    
    var teamRed: Team? {
        guard isATeamMode else {
            return nil
        }
        var redPlayers = [Player]()
        guard let playersInRedTeam = redPlayersInRules?.components(separatedBy: " ") else {
            return Team(type: .red, score: "--", players: redPlayers)
        }
        guard let scoreRedTeam = teamRedScoreInRules else {
            return Team(type: .red, score: "--", players: redPlayers)
        }
        playersInRedTeam.forEach { position in
            if let index = Int(position), index - 1 < players.count, index - 1 >= 0 {
                redPlayers.append(players[index - 1])
            }
        }
        redPlayers.sort { (first, second) -> Bool in
            return Int(first.score) ?? 0 > Int(second.score) ?? 0
        }
        return Team(type: .red, score: scoreRedTeam, players: redPlayers)
    }
    
    var teamBlue: Team? {
        guard isATeamMode else {
            return nil
        }
        var bluePlayers = [Player]()
        guard let playersInBlueTeam = bluePlayersInRules?.components(separatedBy: " ") else {
            return Team(type: .blue, score: "--", players: bluePlayers)
        }
        guard let scoreBlueTeam = teamBlueScoreInRules else {
            return Team(type: .blue, score: "--", players: bluePlayers)
        }
        playersInBlueTeam.forEach { position in
            if let index = Int(position), index - 1 < players.count, index - 1 >= 0 {
                bluePlayers.append(players[index - 1])
            }
        }
        bluePlayers.sort { (first, second) -> Bool in
            return Int(first.score) ?? 0 > Int(second.score) ?? 0
        }
        return Team(type: .blue, score: scoreBlueTeam, players: bluePlayers)
    }
    
    private var redPlayersInRules: String? {
        return rules.first(where: { $0.key.lowercased() == "players_red" })?.value
    }
    
    private var bluePlayersInRules: String? {
        return rules.first(where: { $0.key.lowercased() == "players_blue" })?.value
    }
    
    private var teamRedScoreInRules: String? {
        return rules.first(where: { $0.key.lowercased() == "score_red" })?.value
    }
    
    private var teamBlueScoreInRules: String? {
        return rules.first(where: { $0.key.lowercased() == "score_blue" })?.value
    }
}
