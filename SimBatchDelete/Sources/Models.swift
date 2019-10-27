//
//  Models.swift
//

import Foundation

struct SimViewModel {

    let identifier: UUID

    let name: String
    let version: String
    let available: String
    let state: String
    let comment: String
}

enum Column: String {

    case checkbox
    case name
    case version
    case isAvailable
    case state
    case comment
}
