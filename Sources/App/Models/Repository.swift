//
//  Repository.swift
//  Repository
//
//  Created by Oguz Sutanrikulu on 11.12.19.
//

import Vapor
import Fluent

///LI.CO.RE's representation of a`Repository`defining a `schema` for the persistence layer.
///This class contains the project's `scmId`, `name`.
///The `scmId` is the id value of the pull request at the remote source control management system.
///It has a parent relation to `LicoreProject`and two children relations to `Branch` and `PullRequest`.
///A `Repository` has also two siblings relations to `Developer` and to `Reviewer`.
public final class Repository: Model, Content {
    
    public typealias IDValue = Int
    
    public static var schema: String = "repositories"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Field(key: "scm_id")
    public var scmId: Int
    
    @Field(key: "name")
    public var name: String
    
    @Parent(key: "project_id")
    public var project: LicoreProject
    
    @Children(for: \.$repository)
    public var branches: [Branch]
    
    @Children(for: \.$repository)
    public var pullRequests: [PullRequest]
    
    @Siblings(through: RepositoryDeveloper.self, from: \.$repository, to: \.$developer)
    public var developers: [Developer]
    
    @Siblings(through: RepositoryReviewer.self, from: \.$repository, to: \.$reviewer)
    public var reviewers: [Reviewer]
    
    public init() { }
    
    init(id: Int? = nil, scmId: Int, name: String, projectID: LicoreProject.IDValue) {
        self.id = id
        self.scmId = scmId
        self.name = name
        self.$project.id = projectID
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
    }
    
}

extension Repository {
    struct RepostioryMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("repositories")
                .field("id", .int, .identifier(auto: true))
                .field("scm_id", .int, .required)
                .field("name", .string, .required)
                .field("project_id", .int, .required, .references("projects", "id", onDelete: .cascade, onUpdate: .cascade))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("repositories").delete()
        }
    }
}

extension Repository: Equatable {
    public static func == (lhs: Repository, rhs: Repository) -> Bool {
        return lhs.id == rhs.id
    }
}
