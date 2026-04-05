//
//  MasterServer.swift
//  
//
//  Created by Andrea G on 07/09/2023.
//

import Foundation

public struct MasterServer: Identifiable, CustomStringConvertible, Sendable {
    /// Stable identity derived from the host/port pair.  Using `description`
    /// as the List id was fragile because two servers on the same host with
    /// different ports could theoretically share the same rendered label.
    public var id: String { "\(hostname):\(port)" }
    public let hostname: String
    public let port: String

    public var description: String {
        return "\(hostname):\(port)"
    }
}
