//
//  BitBucketIncomingWebhook.swift
//  App
//
//  Created by Oguz Sutanrikulu on 06.01.20.
//

import Vapor

public enum PullRequestStatus: String, Codable {
    case approved = "APPROVED"
    case unapproved = "UNAPPROVED"
    case rework = "NEEDS_WORK"
}

struct Changes: Content {
    let ref: [String: String]
    let refId: String
    let toHash: String
    let type: String
}

struct BitBucketWebhookResponse: Content {
    let eventKey: String
    let date: String
    let pullRequest: BitBucketPullRequestResponse?
    let repository: BitBucketRepositoryResponse?
    let changes: [Changes]?
    let previousStatus: PullRequestStatus?
    
    init(eventKey: String,
         date: String,
         pullRequest: BitBucketPullRequestResponse?,
         repository: BitBucketRepositoryResponse?,
         changes: [Changes]?,
         previousStatus: PullRequestStatus? = nil) {
        self.eventKey = eventKey
        self.date = date
        self.pullRequest = pullRequest
        self.repository = repository
        self.changes = changes
        self.previousStatus = previousStatus
    }
    
    private enum CodingKeys: String, CodingKey {
        case eventKey
        case date
        case pullRequest
        case repository
        case changes
        case previousStatus
    }
}
