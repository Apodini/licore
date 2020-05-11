//
//  Developer.swift
//  App
//
//  Created by Oguz Sutanrikulu on 09.02.20.
//

import Vapor
import Fluent

final class Developer: Content, Model {
    
    static var schema: String = "developers"
    
    @ID(custom: "id")
    var id: Int?
    
    @Field(key: "slug")
    var slug: String
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "email")
    var email: String
    
    @Siblings(through: RepositoryDeveloper.self, from: \.$developer, to: \.$repository)
    var repository: [Repository]
    
    @Children(for: \.$developer)
    var reviewStatistics: [ReviewStatistics]
    
    init() { }
    
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
