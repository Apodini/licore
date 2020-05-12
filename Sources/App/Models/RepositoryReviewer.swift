//
//  RepositoryReviewer.swift
//  App
//
//  Created by Oguz Sutanrikulu on 07.03.20.
//

import Vapor
import Fluent

///This class holds the siblings relation between a 'Repository' and 'Reviewer'.
public final class RepositoryReviewer: Model {
    
    public static let schema: String = "repository_reviewer"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Parent(key: "repository_id")
    public var repository: Repository
    
    @Parent(key: "reviewer_id")
    public var reviewer: Reviewer
    
    public init() {}
    
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
