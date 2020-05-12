//
//  Developer.swift
//  App
//
//  Created by Oguz Sutanrikulu on 09.02.20.
//

import Vapor
import Fluent

///Representation of a 'Developer' defining a 'schema' for the persistence layer.
///This class contains the developer's 'slug', 'name', and 'email'.
///It has a siblings relation to 'Repository' and a children relation to 'ReviewStatistics'.
public final class Developer: Content, Model {
    
    public static var schema: String = "developers"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Field(key: "slug")
    public var slug: String
    
    @Field(key: "name")
    public var name: String
    
    @Field(key: "email")
    public var email: String
    
    @Siblings(through: RepositoryDeveloper.self, from: \.$developer, to: \.$repository)
    public var repository: [Repository]
    
    @Children(for: \.$developer)
    public var reviewStatistics: [ReviewStatistics]
    
    public init() { }
    
    init(id: Int? = nil, slug: String, name: String, email: String) {
        self.id = id
        self.slug = slug
        self.name = name
        self.email = email
    }
    
}

extension Developer {
    struct DeveloperMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("developers")
                .field("id", .int, .identifier(auto: true))
                .field("slug", .string, .required).unique(on: "slug")
                .field("name", .string, .required)
                .field("email", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("developers").delete()
        }
    }
}
