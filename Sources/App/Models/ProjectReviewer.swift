//
//  ProjectReviewer.swift
//  App
//
//  Created by Oguz Sutanrikulu on 04.03.20.
//

import Vapor
import Fluent

///This class holds the siblings relation between a `LicoreProject` and `Reviewer`.
public final class ProjectReviewer: Model {
    
    public static let schema: String = "project_reviewer"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Parent(key: "project_id")
    public var project: LicoreProject
    
    @Parent(key: "reviewer_id")
    public var reviewer: Reviewer
    
    public init() {}
    
    init(id: Int? = nil, projectID: Int, reviewerID: Int) {
        self.$project.id = projectID
        self.$reviewer.id = reviewerID
    }
    
}

extension ProjectReviewer {
    struct ProjectReviewerMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("project_reviewer")
                .field("id", .int, .identifier(auto: true))
                .field("project_id", .int, .required, .references("projects", "id", onDelete: .cascade, onUpdate: .cascade))
                .field("reviewer_id", .int, .required, .references("reviewers", "id", onDelete: .cascade, onUpdate: .cascade))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("project_reviewer").delete()
        }
    }
}
