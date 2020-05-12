//
//  ReviewJobData.swift
//  App
//
//  Created by Oguz Sutanrikulu on 10.02.20.
//

import Vapor
import Fluent

//An enum representing the status of a 'ReviewJob'.
public enum JobStatus: String, Codable {
    case new = "New"
    case done = "Done"
    case failed = "Failed"
}

//A persistable class holding a 'JobStatus'.
//It has a parent relation to a 'PullRequest'.
public final class ReviewJobData: Content, Model {
    
    public static var schema: String = "reviewjobs"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Field(key: "status")
    public var status: JobStatus
    
    @Parent(key: "pullrequest_id")
    public var pullRequest: PullRequest
    
    public init() { }
    
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
