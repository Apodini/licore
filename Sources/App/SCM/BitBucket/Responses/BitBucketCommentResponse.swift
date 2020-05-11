//
//  BitBucketCommentResponse.swift
//  App
//
//  Created by Oguz Sutanrikulu on 17.12.19.
//

import Vapor

struct BitBucketCommentResponse: Content {
    let id: Int
    let version: Int?
    let text: String
    let author: BitBucketAuthorResponse
    
    init(id: Int, version: Int? = nil, text: String, author: BitBucketAuthorResponse) {
        self.id = id
        self.version = version
        self.text = text
        self.author = author
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case version
        case text
        case author
    }
}

struct BitBucketAuthorResponse: Content {
    let slug: String
}

extension BitBucketCommentResponse: LicoreModelConvertable {
    func createLicoreModel() -> Comment {
        return Comment(id: self.id,
                       version: self.version,
                       line: 1,
                       lineType: "ADDED",
                       ruleDescription: " ",
                       content: self.text,
                       path: " ",
                       type: .message)
    }
}
