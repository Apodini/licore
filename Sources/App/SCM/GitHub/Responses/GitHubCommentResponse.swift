//
//  GitHubCommentResponse.swift
//  App
//
//  Created by Oguz Sutanrikulu on 18.12.19.
//

import Vapor

struct GitHubCommentResponse: Content {
    let id: Int
    let body: String
    
    init(id: Int, body: String) {
        self.id = id
        self.body = body
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case body
    }
}

extension GitHubCommentResponse: LicoreModelConvertable {
    func createLicoreModel() -> Comment {
        return Comment(id: self.id, line: 0, lineType: nil, ruleDescription: " ", content: " ", path: nil, type: nil)
    }
}
