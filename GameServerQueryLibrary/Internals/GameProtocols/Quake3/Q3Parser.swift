//
//  Q3Parser.swift
//  ServerQueryLibrary
//
//  Created by Andrea Giavatto on 12/14/13.
//
//

import Foundation

class Q3Parser: Parsable {
    private static let getServersResponseMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x67, 0x65, 0x74, 0x73, 0x65, 0x72, 0x76, 0x65, 0x72, 0x73, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x5c] // YYYYgetserversResponse\
    private static let eotMarker: [UInt8] = [0x5c, 0x45, 0x4f, 0x54] // \EOT
    private static let infoResponseMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x69, 0x6e, 0x66, 0x6f, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x0a, 0x5c] // YYYYinfoResponse\n\
    private static let statusResponseMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x0a, 0x5c] // YYYYstatusResponse\n\
    
    static func parseServers(_ data: Data) -> [String] {
        var actualData = data
        let asciiRep = asciiString(from: data)
        let prefix = asciiString(from: getServersResponseMarker)
        if asciiRep.starts(with: prefix) {
            let actualDataStart = actualData.index(actualData.startIndex, offsetBy: getServersResponseMarker.count)
            actualData = actualData.subdata(in: actualDataStart..<actualData.endIndex)
        }
        let suffix = asciiString(from: eotMarker)
        if asciiRep.range(of: suffix, options: .backwards, range: nil, locale: nil) != nil {
            let actualDataEnd = actualData.index(actualData.endIndex, offsetBy: -(eotMarker.count+3))
            actualData = actualData.subdata(in: actualData.startIndex..<actualDataEnd)
        }
        
        if actualData.count > 0 {
            
            let len: Int = actualData.count
            var servers = [String]()
            for i in 0..<len {
                if i > 0 && i % 7 == 0 {
                    // -- 4 bytes for ip, 2 for port, 1 separator
                    let s = actualData.index(actualData.startIndex, offsetBy: i-7)
                    let e = actualData.index(s, offsetBy: 7)
                    let server = parseServerData(actualData.subdata(in: s..<e))
                    servers.append(server)
                }
            }
            
            return servers
        }
        
        return []
    }
    
    static func parseServer(_ data: Data) -> [String: String]? {
        
        guard data.count > 0 else {
            return nil
        }
        
        var infoResponse = asciiString(from: data)
        infoResponse = infoResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let prefix = asciiString(from: infoResponseMarker)
        if infoResponse.starts(with: prefix) {
            let actualDataStart = infoResponse.index(infoResponse.startIndex, offsetBy: prefix.count)
            infoResponse = String(infoResponse[actualDataStart...])
        }
        
        var info = infoResponse.components(separatedBy: "\\")
        info = info.filter { NSPredicate(format: "SELF != ''").evaluate(with: $0) }
        var keys = [String]()
        var values = [String]()
        
        for (index, element) in info.enumerated() {
            if index % 2 == 0 {
                keys.append(element)
            } else {
                values.append(element)
            }
        }
        
        if keys.count == values.count {
            
            var infoDict = [String: String]()
            keys.enumerated().forEach { (i) -> () in
                infoDict[i.element] = values[i.offset]
            }
            
            return infoDict
        }
        
        return nil
    }
    
    static func parseServerStatus(_ data: Data) -> (rules: [Setting], players: [Player])? {
        
        guard data.count > 0 else {
            return nil
        }
        
        var rules = [Setting]()
        var players = [Player]()
        
        var statusResponse = asciiString(from: data)
        statusResponse = statusResponse.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        let prefix = asciiString(from: statusResponseMarker)
        if statusResponse.starts(with: prefix) {
            let actualDataStart = statusResponse.index(statusResponse.startIndex, offsetBy: prefix.count)
            statusResponse = String(statusResponse[actualDataStart...])
        }
        
        let statusComponents = statusResponse.components(separatedBy: "\n")
        let serverStatus = statusComponents[0]
        if statusComponents.count > 1 {
            // -- We got players
            let playerStrings = statusComponents[1..<statusComponents.count]
            let playersStatus = Array(playerStrings)
            players = parsePlayersStatus(playersStatus)
        }
        var status = serverStatus.components(separatedBy: "\\")
        status = status.filter { NSPredicate(format: "SELF != ''").evaluate(with: $0) }
        var keys = [String]()
        var values = [String]()
        
        for (index, element) in status.enumerated() {
            if index % 2 == 0 {
                keys.append(element)
            } else {
                values.append(element)
            }
        }
        
        if keys.count == values.count {
            keys.enumerated().forEach { (i) -> () in
                rules.append(Setting(key: i.element, value: values[i.offset]))
            }
        }
        
        return (rules, players)
    }
    
    // MARK: - Private methods
    
    private static func parseServerData(_ data: Data) -> String {
        
        let len: Int = data.count
        let bytes = [UInt8](data)
        var port: UInt32 = 0
        var server = String()
        for i in 0..<len - 1 {
            
            if i < 4 {
                if i < 3 {
                    server = server.appendingFormat("%d.", bytes[i])
                }
                else {
                    server = server.appendingFormat("%d", bytes[i])
                }
            }
            else {
                if i == 4 {
                    port += UInt32(bytes[i]) << 8
                }
                else {
                    port += UInt32(bytes[i])
                }
            }
        }
        return "\(server):\(port)"
    }
    
    private static func parsePlayersStatus(_ players: [String]) -> [Player] {
        
        guard players.count > 0 else {
            return []
        }
        
        var q3Players = [Player]()
        
        for playerString in players {
            if let player = Player(line: playerString) {
                q3Players.append(player)
            }
        }
        
        return q3Players
    }
    
    private static func asciiString(from data: Data) -> String {
        String(decoding: bytesFromData(data), as: Unicode.ASCII.self)
    }
    
    private static func asciiString(from bytes: [UInt8]) -> String {
        String(decoding: bytes, as: Unicode.ASCII.self)
    }
    
    private static func bytesFromData(_ data: Data) -> [UInt8] {
        data.withUnsafeBytes { pointer in
            [UInt8](UnsafeBufferPointer(start: pointer, count: data.count))
        }
    }
}
