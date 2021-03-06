//
//  Branch.swift
//  App
//
//  Created by Oguz Sutanrikulu on 14.02.20.
//

import Vapor
import Fluent

///LI.CO.RE's representation of a `Branch` defining a `schema for the persistence layer.
public final class Branch: Model, Content {
    
    public static var schema: String = "branches"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Field(key: "creation_date")
    public var creationDate: Double
    
    @Field(key: "ref_id")
    public var refId: String
    
    @Parent(key: "repository_id")
    public var repository: Repository
    
    public init() { }
    
    init(id: Int? = nil, creationDate: Double, refId: String, repositoryID: Repository.IDValue) {
        self.id = id
        self.creationDate = creationDate
        self.refId = refId
        self.$repository.id = repositoryID
    }
}

extension Branch {
    struct BranchMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("branches")
                .field("id", .int, .identifier(auto: true))
                .field("creation_date", .double, .required)
                .field("ref_id", .string, .required)
                .field("repository_id", .int, .references("repositories", "id", onDelete: .cascade, onUpdate: .cascade))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("branches").delete()
        }
    }
}
