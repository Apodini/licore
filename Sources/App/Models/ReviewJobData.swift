//
//  ReviewJobData.swift
//  App
//
//  Created by Oguz Sutanrikulu on 10.02.20.
//

import Vapor
import Fluent

public enum JobStatus: String, Codable {
    case new = "New"
    case done = "Done"
    case failed = "Failed"
}

public final class ReviewJobData: Content, Model {
    
    static var schema: String = "reviewjobs"
    
    @ID(custom: "id")
    var id: Int?
    
    @Field(key: "status")
    var status: JobStatus
    
    @Parent(key: "pullrequest_id")
    var pullRequest: PullRequest
    
    init() { }
    
    public init(id: Int? = nil, status: JobStatus = .new, pullRequestID: PullRequest.IDValue) {
        self.id = id
        self.status = status
        self.$pullRequest.id = pullRequestID
    }
}

extension ReviewJobData {
    struct ReviewJobDataMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("reviewjobs")
                .field("id", .int, .identifier(auto: true))
                .field("status", .string, .required)
                .field("pullrequest_id", .int, .required, .references("pullrequests", "id", onDelete: .cascade, onUpdate: .cascade))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("reviewjobs").delete()
        }
    }
}
