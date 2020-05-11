//
//  Repository.swift
//  Repository
//
//  Created by Oguz Sutanrikulu on 11.12.19.
//

import Vapor
import Fluent

final class Repository: Model, Content {
    
    typealias IDValue = Int
    
    static var schema: String = "repositories"
    
    @ID(custom: "id")
    var id: Int?
    
    @Field(key: "scm_id")
    var scmId: Int
    
    @Field(key: "name")
    var name: String
    
    @Parent(key: "project_id")
    var project: LicoreProject
    
    @Children(for: \.$repository)
    var branches: [Branch]
    
    @Children(for: \.$repository)
    var pullRequests: [PullRequest]
    
    @Siblings(through: RepositoryDeveloper.self, from: \.$repository, to: \.$developer)
    var developers: [Developer]
    
    @Siblings(through: RepositoryReviewer.self, from: \.$repository, to: \.$reviewer)
    var reviewers: [Reviewer]
    
    init() { }
    
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
    static func == (lhs: Repository, rhs: Repository) -> Bool {
        return lhs.id == rhs.id
    }
}
