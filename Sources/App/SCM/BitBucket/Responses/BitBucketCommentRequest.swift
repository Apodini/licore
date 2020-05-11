//
//  BitBucketCommentRequest.swift
//  App
//
//  Created by Oguz Sutanrikulu on 12.01.20.
//

import Vapor

struct CommentAnchor: Content {
    let fromHash: String
    let toHash: String
    let line: Int
    let lineType: String
    let filetype: String
    let path: String
    let diffType: String
}

struct BitBucketCommentRequest: Content {
    let anchor: CommentAnchor
    let text: String
    
    init(anchor: CommentAnchor, text: String) {
        self.anchor = anchor
        self.text = text
    }
    
    private enum CodingKeys: String, CodingKey {
        case anchor
        case text
    }
}
