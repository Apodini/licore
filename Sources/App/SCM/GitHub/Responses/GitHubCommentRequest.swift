//
//  GitHubCommentRequest.swift
//  App
//
//  Created by Oguz Sutanrikulu on 24.03.20.
//

import Vapor

struct GitHubCommentRequest: Content {
    let path: String
    let position: Int
    let body: String
    
    init(path: String, position: Int, body: String) {
        self.path = path
        self.position = position
        self.body = body
    }
    
    private enum CodingKeys: String, CodingKey {
        case path
        case position
        case body
    }
}
