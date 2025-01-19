//
//  GSQLError.swift
//  SQL
//
//  Created by Andrea on 08/06/2018.
//

import Foundation

public enum GSQLError: Error {
    case parseError(Server)
    case custom(String?)
}
