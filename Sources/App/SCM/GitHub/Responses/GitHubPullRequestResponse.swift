//
//  GitHubPullRequestResponse.swift
//  App
//
//  Created by Oguz Sutanrikulu on 18.12.19.
//

import Vapor

struct GitHubPullRequestResponse: Content {
    let number: Int
    let head: Head
    let base: Base
    let createdDate: String
    
    init(number: Int, head: Head, base: Base, createdDate: String) {
        self.number = number
        self.head = head
        self.base = base
        self.createdDate = createdDate
    }
    
    private enum CodingKeys: String, CodingKey {
        case number
        case head
        case base
        case createdDate = "created_at"
    }
    
}

extension GitHubPullRequestResponse: LicoreModelConvertable {
    func createLicoreModel() -> PullRequest? {
        guard let date = ISO8601DateFormatter().date(from: createdDate)?.timeIntervalSince1970 else { return nil }
        
        return PullRequest(scmId: self.number, creationDate: date, latestCommit: self.head.sha, refId: self.head.ref, repositoryID: 0)
    }
}

struct Head: Content {
    let ref: String
    let sha: String
}

struct Base: Content {
    let ref: String
    let sha: String
}
