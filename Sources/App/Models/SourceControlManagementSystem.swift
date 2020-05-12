//
//  SourceControlManagementSystem.swift
//  App
//
//  Created by Oguz Sutanrikulu on 24.02.20.
//

import Vapor
import Fluent

public final class SourceControlManagementSystem: Model, Content {
    
    public static var schema: String = "scmsystems"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "scm_type")
    var scmType: SourceControlType
    
    @Field(key: "scm_url")
    var scmURL: String
    
    @Field(key: "scm_token")
    var token: String
    
    @Children(for: \.$scmSystem)
    var projects: [LicoreProject]
    
    public init() { }
    
    init(id: Int? = nil, name: String, scmType: SourceControlType, scmURL: String, token: String) {
        self.id = id
        self.name = name
        self.scmType = scmType
        self.scmURL = scmURL
        self.token = token
    }
    
}

extension SourceControlManagementSystem {
    struct SourceControlManagementSystemMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("scmsystems")
                .field("id", .int, .identifier(auto: true))
                .field("name", .string, .required)
                .field("scm_type", .string, .required)
                .field("scm_url", .string, .required)
                .field("scm_token", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("scmsystems").delete()
        }
    }
}
