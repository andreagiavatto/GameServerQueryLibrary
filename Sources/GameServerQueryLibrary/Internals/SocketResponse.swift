//
//  SocketResponse.swift
//
//
//  Created by Andrea G on 18/06/2023.
//

import Foundation

public enum SocketError: Error {
    case notReady
    case timeout(String, UInt16)
    case dataNotSent(Error?)
    case closed(Error?)
    case requestAlreadyInProgress
    case unknown
}

public struct SocketResponse: Sendable {
    public let data: Data
    public let runningTime: Int
}
