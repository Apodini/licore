//
//  LicoreProject.swift
//  App
//
//  Created by Oguz Sutanrikulu on 25.01.20.
//

import Vapor
import Fluent

public final class LicoreProject: Model, Content {
    
    static var schema: String = "projects"
    
    @ID(custom: "id")
    var id: Int?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "key")
    var key: String
    
    @Field(key: "rules")
    var rules: String
    
    @Field(key: "slack_token")
    var slackToken: String?
    
    @Parent(key: "scmsystems_id")
    var scmSystem: SourceControlManagementSystem
    
    @Children(for: \.$project)
    var repositories: [Repository]
    
    @Siblings(through: ProjectReviewer.self, from: \.$project, to: \.$reviewer)
    var reviewers: [Reviewer]
    
    init() { }
    
    init(id: Int? = nil, name: String, key: String, rules: String, slackToken: String, scmSystemID: SourceControlManagementSystem.IDValue) {
        self.id = id
        self.name = name
        self.key = key
        self.rules = rules
        self.slackToken = slackToken
        self.$scmSystem.id = scmSystemID
    }
    
}

extension LicoreProject {
    func sourceControlService(req: Request) -> EventLoopFuture<SourceControlServable?> {
        return LicoreProject.query(on: req.db).with(\.$scmSystem).all().flatMap { projects in
            let currentProject = projects.filter { $0.id == self.id }.first
            guard let project = currentProject else { return req.eventLoop.future(nil) }
            
            switch project.scmSystem.scmType {
            case .bitbucket:
                return req.eventLoop.future(BitBucketService(project: self, scmSystem: project.scmSystem))
            case .github:
                return req.eventLoop.future(GitHubService(project: self, scmSystem: project.scmSystem))
            }
        }
    }
}

extension LicoreProject {
    struct LicoreProjectMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("projects")
                .field("id", .int, .identifier(auto: true))
                .field("name", .string, .required)
                .field("key", .string, .required)
                .field("rules", .string, .required)
                .field("slack_token", .string)
                .field("scmsystems_id", .int, .required, .references("scmsystems", "id", onDelete: .cascade, onUpdate: .cascade))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("projects").delete()
        }
    }
}

extension LicoreProject: Equatable {
    static func == (lhs: LicoreProject, rhs: LicoreProject) -> Bool {
        return lhs.id == rhs.id
    }
}
