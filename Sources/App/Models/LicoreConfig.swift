//
//  LicoreConfig.swift
//  App
//
//  Created by Oguz Sutanrikulu on 07.02.20.
//

import Vapor
import Fluent

final class LicoreConfig: Model, Content {
    
    static var schema: String = "configs"
    
    @ID(custom: "id")
    var id: Int?
    
    @Field(key: "hook_url")
    var hookURL: String
    
    init() { }
    
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
