//
//  UserToken.swift
//  App
//
//  Created by Oguz Sutanrikulu on 19.01.20.
//

import Vapor
import Fluent

final class UserToken: Content, Model {
    
    static var schema: String = "usertokens"
    
    @ID(custom: "id")
    var id: Int?
    
    @Field(key: "token")
    var token: String
    
    @Parent(key: "user_id")
    var user: LicoreUser
    
    init() { }
    
    init(id: Int? = nil, token: String, userID: LicoreUser.IDValue) {
        self.id = id
        self.token = token
        self.$user.id = userID
    }
    
}

extension UserToken: ModelUserToken {
    var isValid: Bool {
        return true
    }
    
    static let valueKey = \UserToken.$token
    static let userKey = \UserToken.$user
}

extension UserToken {
    struct UserTokenMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("usertokens")
                .field("id", .int, .identifier(auto: true))
                .field("token", .string, .required)
                .field("user_id", .int, .required)
                .unique(on: "token")
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("usertokens").delete()
        }
    }
}
