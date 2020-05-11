//
//  GitHubStatusRequest.swift
//  App
//
//  Created by Oguz Sutanrikulu on 26.03.20.
//

import Vapor

struct GitHubStatusRequest: Content {
    let state: String
    let context: String
    
    init(state: String, context: String) {
        self.state = state
        self.context = context
    }
    
    private enum CodingKeys: String, CodingKey {
        case state
        case context
    }
}
