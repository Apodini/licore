//
//  BitBucketActivityResponse.swift
//  App
//
//  Created by Oguz Sutanrikulu on 17.12.19.
//

import Vapor

struct BitBucketActivityResponse: Content {
    let id: Int
    let action: String
    let comment: BitBucketCommentResponse?
    
    init(id: Int, action: String, comment: BitBucketCommentResponse?) {
        self.id = id
        self.action = action
        self.comment = comment
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case action
        case comment
    }
}
