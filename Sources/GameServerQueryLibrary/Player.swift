//
//  Player.swift
//  ServerQueryLibrary
//
//  Created by Andrea Giavatto on 3/23/14.
//
//

import Foundation

public final class Player: Identifiable {
    
    public let name: String
    public let ping: String
    public let score: String

    public required init?(line: String) {
        guard !line.isEmpty else {
            return nil
        }
        
        let playerComponents = line.components(separatedBy: CharacterSet.whitespaces)
        guard playerComponents.count >= 3 else {
            return nil
        }
        
        self.score = playerComponents[0]
        self.ping = playerComponents[1]
        let restOfName = Array(playerComponents[2...])
        let tempName: String
        if restOfName.count > 1 {
            tempName = restOfName.joined(separator: " ")
        } else {
            tempName = restOfName.first ?? ""
        }
        self.name = tempName.q3ColorDecoded.replacingOccurrences(of: "\"", with: "")
    }
}

extension Player: CustomStringConvertible {
    
    public var description: String {
        return "<Player> \(name) (\(ping)) - \(score)"
    }
}
