//
//  Q3Controller.swift
//  GameServerQueryLibrary
//
//  Created by Andrea Giavatto on 18/12/2022.
//

import Foundation

enum Q3MasterError: Error {
    case invalidPort
    case invalidData
}

class Q3Master {
    
    private let getServersRequestMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x67, 0x65, 0x74, 0x73, 0x65, 0x72, 0x76, 0x65, 0x72, 0x73, 0x20, 0x36, 0x38, 0x20, 0x65, 0x6d, 0x70, 0x74, 0x79, 0x20, 0x66, 0x75, 0x6c, 0x6c] // YYYYgetservers 68 empty full
    private let getServersResponseMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x67, 0x65, 0x74, 0x73, 0x65, 0x72, 0x76, 0x65, 0x72, 0x73, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x5c] // YYYYgetserversResponse\
    private let eotMarker: [UInt8] = [0x5c, 0x45, 0x4f, 0x54] // \EOT
    
    private var socketWrapper: AsyncSocketWrapper?
    
    func getServers(ip: String, port: String) async throws -> [Server] {
        guard let port = UInt16(port) else {
            throw Q3MasterError.invalidPort
        }
        
        let newSocket = AsyncSocketWrapper(timeout: 10)
        socketWrapper = newSocket
        let response = try await newSocket.sendRequest(ip: ip, port: port, requestMarker: getServersRequestMarker, responseMarker: getServersResponseMarker, eotMarker: eotMarker)
        let ips = Q3Parser.parseServers(response.data)
        let servers: [Server] = ips.compactMap { ip in
            let address: [String] = ip.components(separatedBy: ":")
            guard address.count == 2 else {
                return nil
            }
            return Server(ip: address[0], port: address[1])
        }
        return servers
    }
}
