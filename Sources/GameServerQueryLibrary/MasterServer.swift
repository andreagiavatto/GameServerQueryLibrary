//
//  MasterServer.swift
//  
//
//  Created by Andrea G on 07/09/2023.
//

import Foundation

public struct MasterServer: CustomStringConvertible {
    public let hostname: String
    public let port: String
    
    public var description: String {
        return "\(hostname):\(port)"
    }
}
