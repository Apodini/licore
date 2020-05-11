//
//  GitHubWebhookRequest.swift
//  App
//
//  Created by Oguz Sutanrikulu on 26.03.20.
//

import Vapor

struct GitHubWebhookRequest: Content {
    let name: String
    let config: GitHubWebhookConfig
    let events: [String]
    
    init(name: String, config: GitHubWebhookConfig, events: [String]) {
        self.name = name
        self.config = config
        self.events = events
    }
    
    private enum CodingKeys: String, CodingKey {
        case name
        case config
        case events
    }
}

struct GitHubWebhookConfig: Content {
    let url: String
    let contentType: String
    
    init(url: String, contentType: String) {
        self.url = url
        self.contentType = contentType
    }
    
    private enum CodingKeys: String, CodingKey {
        case url
        case contentType
    }
}
