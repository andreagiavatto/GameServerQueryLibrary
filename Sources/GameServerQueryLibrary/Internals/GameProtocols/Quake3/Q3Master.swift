//
//  Q3Controller.swift
//  GameServerQueryLibrary
//
//  Created by Andrea Giavatto on 18/12/2022.
//

import Foundation
import Network

enum Q3MasterError: Error {
    case invalidPort
    case invalidData
    case cancelled
}

final class Q3Master {
    private let getServersRequestMarker: [UInt8] = [0xff, 0xff, 0xff, 0xff, 0x67, 0x65, 0x74, 0x73, 0x65, 0x72, 0x76, 0x65, 0x72, 0x73, 0x20, 0x36, 0x38, 0x20, 0x65, 0x6d, 0x70, 0x74, 0x79, 0x20, 0x66, 0x75, 0x6c, 0x6c] // YYYYgetservers 68 empty full
    private let socketWrapper: AsyncSocketWrapper
    
    init?(host: String, port: String) {
        let host = NWEndpoint.Host(host)
        guard let serverPort = UInt16(port), let port = NWEndpoint.Port(rawValue: serverPort) else {
            return nil
        }
        socketWrapper = AsyncSocketWrapper(requestMarker: getServersRequestMarker, host: host, port: port)
    }
    
    func getServers() async throws -> [Server] {
        let response = try await socketWrapper.sendRequest()
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
