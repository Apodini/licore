//
//  GitHubTopCommentRequest.swift
//  App
//
//  Created by Oguz Sutanrikulu on 25.03.20.
//

import Vapor

struct GitHubTopCommentRequest: Content {
    let body: String
    let event: String
    
    init(body: String, event: String) {
        self.body = body
        self.event = event
    }
    
    private enum CodingKeys: String, CodingKey {
        case body
        case event
    }
}
