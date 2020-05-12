//
//  SourceControlManagementSystem.swift
//  App
//
//  Created by Oguz Sutanrikulu on 24.02.20.
//

import Vapor
import Fluent

//LI.CO.RE's representation of a 'SourceControlManagementSystem' (SCM) defining a 'schema' for the persistence layer.
//This class contains the SCM's 'name', 'scmType' definig the SCM provider, 'scmURL' the URL to the actual SCM System, and the 'token' for the SCM authentication.
//It has a a childrens relation to 'LicoreProject'.
public final class SourceControlManagementSystem: Model, Content {
    
    public static var schema: String = "scmsystems"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Field(key: "name")
    public var name: String
    
    @Field(key: "scm_type")
    public var scmType: SourceControlType
    
    @Field(key: "scm_url")
    public var scmURL: String
    
    @Field(key: "scm_token")
    public var token: String
    
    @Children(for: \.$scmSystem)
    public var projects: [LicoreProject]
    
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
