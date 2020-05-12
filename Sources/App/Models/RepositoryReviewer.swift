//
//  RepositoryReviewer.swift
//  App
//
//  Created by Oguz Sutanrikulu on 07.03.20.
//

import Vapor
import Fluent

public final class RepositoryReviewer: Model {
    
    static let schema: String = "repository_reviewer"
    
    @ID(custom: "id")
    var id: Int?
    
    @Parent(key: "repository_id")
    var repository: Repository
    
    @Parent(key: "reviewer_id")
    var reviewer: Reviewer
    
    init() {}
    
    init(id: Int? = nil, repositoryID: Int, reviewerID: Int) {
        self.$repository.id = repositoryID
        self.$reviewer.id = reviewerID
    }
    
}

extension RepositoryReviewer {
    struct RepositoryReviewerMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("repository_reviewer")
                .field("id", .int, .identifier(auto: true))
                .field("repository_id", .int, .required, .references("repositories", "id", onDelete: .cascade, onUpdate: .cascade))
                .field("reviewer_id", .int, .required, .references("reviewers", "id", onDelete: .cascade, onUpdate: .cascade))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("repository_reviewer").delete()
        }
    }
}
