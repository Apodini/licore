//
//  RepositoryDeveloper.swift
//  App
//
//  Created by Oguz Sutanrikulu on 27.03.20.
//

import Vapor
import Fluent

///This class holds the siblings relation between a`Repository` and `Developer`.
public final class RepositoryDeveloper: Model {
    
    public static let schema: String = "repository_developer"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Parent(key: "repository_id")
    public var repository: Repository
    
    @Parent(key: "developer_id")
    public var developer: Developer
    
    public init() {}
    
    init(id: Int? = nil, repositoryID: Int, developerID: Int) {
        self.$repository.id = repositoryID
        self.$developer.id = developerID
    }
    
}

extension RepositoryDeveloper {
    struct RepositoryDeveloperMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("repository_developer")
                .field("id", .int, .identifier(auto: true))
                .field("repository_id", .int, .required, .references("repositories", "id", onDelete: .cascade, onUpdate: .cascade))
                .field("developer_id", .int, .required, .references("developers", "id", onDelete: .cascade, onUpdate: .cascade))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("repository_developer").delete()
        }
    }
}
