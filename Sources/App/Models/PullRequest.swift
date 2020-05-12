//
//  PullRequest.swift
//  App
//
//  Created by Oguz Sutanrikulu on 16.12.19.
//

import Vapor
import Fluent

public final class PullRequest: Model, Content {
    
    public static var schema: String = "pullrequests"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Field(key: "scm_id")
    var scmId: Int
    
    @Field(key: "creation_date")
    var creationDate: Double
    
    @Field(key: "latest_commit")
    var latestCommit: String
    
    @Field(key: "ref_id")
    var refId: String?
    
    @Parent(key: "repository_id")
    var repository: Repository
    
    @Children(for: \.$pullRequest)
    var statusChanges: [StatusChange]
    
    public init() { }
    
    init(id: Int? = nil, scmId: Int, creationDate: Double, latestCommit: String, refId: String?, repositoryID: Repository.IDValue) {
        self.id = id
        self.scmId = scmId
        self.creationDate = creationDate
        self.latestCommit = latestCommit
        self.refId = refId
        self.$repository.id = repositoryID
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case latestCommit
        case repository
        case refId
    }
    
}

extension PullRequest {
    struct PullRequestMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("pullrequests")
                .field("id", .int, .identifier(auto: true))
                .field("scm_id", .int, .required)
                .field("creation_date", .double, .required)
                .field("latest_commit", .string, .required)
                .field("ref_id", .string, .required)
                .field("repository_id", .int, .references("repositories", "id", onDelete: .cascade, onUpdate: .cascade))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("pullrequests").delete()
        }
    }
}
