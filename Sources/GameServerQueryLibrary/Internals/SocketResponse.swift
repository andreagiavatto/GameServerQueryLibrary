//
//  SocketResponse.swift
//
//
//  Created by Andrea G on 18/06/2023.
//

import Foundation

enum SocketError: Error {
    case timeout(String, UInt16)
    case dataNotSent(Error?)
    case closed(Error?)
    case unknown
}

struct SocketResponse {
    let data: Data
    let runningTime: Int
}
