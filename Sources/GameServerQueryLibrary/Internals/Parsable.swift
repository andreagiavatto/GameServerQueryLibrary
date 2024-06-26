//
//  Parsable.swift
//  SQL
//
//  Created by Andrea on 28/05/2018.
//

import Foundation

protocol Parsable {
    static func parseServers(_ data: Data) -> [String]
    static func parseServer(_ data: Data) -> [String: String]?
    static func parseServerStatus(_ data: Data) -> (rules: [Setting], players: [Player])?
}
