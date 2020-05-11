//
//  BitBucketTaskRequest.swift
//  App
//
//  Created by Oguz Sutanrikulu on 11.01.20.
//

import Vapor

struct TaskAnchor: Content {
    let id: Int
    let type: String
}

struct BitBucketTaskRequest: Content {
    let anchor: TaskAnchor
    let text: String
    let state: String
    
    init(anchor: TaskAnchor, text: String, state: String) {
        self.anchor = anchor
        self.text = text
        self.state = state
    }
    
    private enum CodingKeys: String, CodingKey {
        case anchor
        case text
        case state
    }
}
