//
//  LicoreConfig.swift
//  App
//
//  Created by Oguz Sutanrikulu on 07.02.20.
//

import Vapor
import Fluent

public final class LicoreConfig: Model, Content {
    
    public static var schema: String = "configs"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Field(key: "hook_url")
    var hookURL: String
    
    public init() { }
    
    init(id: Int? = nil, hookURL: String) {
        self.id = id
        self.hookURL = hookURL
    }
    
}

extension LicoreConfig {
    struct LicoreConfigMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("configs")
                .field("id", .int, .identifier(auto: true))
                .field("hook_url", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("configs").delete()
        }
    }
}
