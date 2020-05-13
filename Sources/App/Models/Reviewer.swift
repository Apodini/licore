//
//  Reviewer.swift
//  App
//
//  Created by Oguz Sutanrikulu on 08.02.20.
//

import Vapor
import Fluent

///Representation of a `Reviewer` defining a `schema` for the persistence layer.
///This class contains the developer's `slug`, `name`, and `email`.
///It has two siblings relations to `LicoreProject` and to `Repository`.
public final class Reviewer: Content, Model {
    
    public static var schema: String = "reviewers"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Field(key: "slug")
    public var slug: String
    
    @Field(key: "name")
    public var name: String
    
    @Field(key: "email")
    public var email: String

    @Siblings(through: ProjectReviewer.self, from: \.$reviewer, to: \.$project)
    public var projects: [LicoreProject]
    
    @Siblings(through: RepositoryReviewer.self, from: \.$reviewer, to: \.$repository)
    public var repositories: [Repository]
    
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
