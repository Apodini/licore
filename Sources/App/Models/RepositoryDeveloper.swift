//
//  RepositoryDeveloper.swift
//  App
//
//  Created by Oguz Sutanrikulu on 27.03.20.
//

import Vapor
import Fluent

final class RepositoryDeveloper: Model {
    
    static let schema: String = "repository_developer"
    
    @ID(custom: "id")
    var id: Int?
    
    @Parent(key: "repository_id")
    var repository: Repository
    
    @Parent(key: "developer_id")
    var developer: Developer
    
    init() {}
    
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
