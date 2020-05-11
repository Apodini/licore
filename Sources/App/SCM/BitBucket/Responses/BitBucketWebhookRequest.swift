//
//  BitBucketWebhookRequest.swift
//  App
//
//  Created by Oguz Sutanrikulu on 26.03.20.
//

import Vapor

struct BitBucketWebhookRequest: Content {
    let name: String
    let events: [String]
    let url: String
    
    public init(name: String, events: [String], url: String) {
        self.name = name
        self.events = events
        self.url = url
    }
    
    private enum CodingKeys: String, CodingKey {
        case name
        case events
        case url
    }
}
