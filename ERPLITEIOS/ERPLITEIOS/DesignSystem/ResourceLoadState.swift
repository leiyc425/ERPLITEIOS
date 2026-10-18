//
//  ResourceLoadState.swift
//  ERPLITEIOS
//

import Foundation

enum ResourceLoadState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(String)

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
