//
//  Reviewer.swift
//  App
//
//  Created by Oguz Sutanrikulu on 08.02.20.
//

import Vapor
import Fluent

public final class Reviewer: Content, Model {
    
    public static var schema: String = "reviewers"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Field(key: "slug")
    var slug: String
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "email")
    var email: String

    @Siblings(through: ProjectReviewer.self, from: \.$reviewer, to: \.$project)
    var projects: [LicoreProject]
    
    @Siblings(through: RepositoryReviewer.self, from: \.$reviewer, to: \.$repository)
    var repositories: [Repository]
    
    public init() { }
    
    init(id: Int? = nil, slug: String, name: String, email: String) {
        self.id = id
        self.slug = slug
        self.name = name
        self.email = email
    }
    
}

extension Reviewer {
    struct ReviewerMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("reviewers")
                .field("id", .int, .identifier(auto: true))
                .field("slug", .string, .required)
                .field("name", .string, .required)
                .field("email", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("reviewers").delete()
        }
    }
}
