//
//  BitBucketPullRequestResponse.swift
//  App
//
//  Created by Oguz Sutanrikulu on 16.12.19.
//

import Vapor

struct FromRef: Content {
    let id: String
    let latestCommit: String
    let repository: BitBucketRepositoryResponse
}

struct ToRef: Content {
    let id: String
}

struct BitBucketPullRequestResponse: Content {
    let id: Int
    let fromRef: FromRef
    let createdDate: Double
    
    init(id: Int, fromRef: FromRef, createdDate: Double) {
        self.id = id
        self.fromRef = fromRef
        self.createdDate = createdDate
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case fromRef
        case createdDate
    }
}

extension BitBucketPullRequestResponse: LicoreModelConvertable {
    func createLicoreModel() -> PullRequest {
        return PullRequest(scmId: self.id,
                           creationDate: createdDate,
                           latestCommit: self.fromRef.latestCommit,
                           refId: fromRef.id,
                           repositoryID: 0)
    }
}
