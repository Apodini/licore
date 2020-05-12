//
//  StatusChange.swift
//  App
//
//  Created by Oguz Sutanrikulu on 23.02.20.
//

import Vapor
import Fluent

public final class StatusChange: Content, Model {
    
    static var schema: String = "statuschanges"
    
    @ID(custom: "id")
    var id: Int?
    
    @Field(key: "previous_status")
    var previousStatus: PullRequestStatus
    
    @Field(key: "new_status")
    var newStatus: PullRequestStatus
    
    @Field(key: "date")
    var date: Double
    
    @Parent(key: "pullrequest_id")
    var pullRequest: PullRequest
    
    init() { }
    
    public init(id: Int? = nil, previousStatus: PullRequestStatus, newStatus: PullRequestStatus, date: Double, pullRequestID: PullRequest.IDValue) {
        self.id = id
        self.previousStatus = previousStatus
        self.newStatus = newStatus
        self.date = date
        self.$pullRequest.id = pullRequestID
    }
}

extension StatusChange {
    struct StatusChangeMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("statuschanges")
                .field("id", .int, .identifier(auto: true))
                .field("previous_status", .string, .required)
                .field("new_status", .string, .required)
                .field("date", .double, .required)
                .field("pullrequest_id", .int, .required, .references("pullrequests", "id", onDelete: .cascade, onUpdate: .cascade))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("statuschanges").delete()
        }
    }
}
