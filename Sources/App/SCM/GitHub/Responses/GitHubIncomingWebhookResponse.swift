//
//  GitHubIncomingWebhook.swift
//  App
//
//  Created by Oguz Sutanrikulu on 21.03.20.
//

import Vapor

struct GitHubWebhookResponse: Content {
    var eventKey: String?
    let action: String?
    let ref: String?
    let pullRequest: GitHubPullRequestResponse?
    let repository: GitHubRepositoryResponse?
    let organization: GitHubOrganizationResponse?
    
    init(eventKey: String?,
         action: String?,
         ref: String?,
         pullRequest: GitHubPullRequestResponse?,
         repository: GitHubRepositoryResponse?,
         organization: GitHubOrganizationResponse?) {
        self.eventKey = eventKey
        self.action = action
        self.ref = ref
        self.pullRequest = pullRequest
        self.repository = repository
        self.organization = organization
    }
    
    private enum CodingKeys: String, CodingKey {
        case eventKey
        case action
        case ref
        case pullRequest = "pull_request"
        case repository
        case organization
    }
}
