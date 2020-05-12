//
//  UserToken.swift
//  App
//
//  Created by Oguz Sutanrikulu on 19.01.20.
//

import Vapor
import Fluent

public final class UserToken: Content, Model {
    
    public static var schema: String = "usertokens"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Field(key: "token")
    var token: String
    
    @Parent(key: "user_id")
    var user: LicoreUser
    
    public init() { }
    
    init(id: Int? = nil, token: String, userID: LicoreUser.IDValue) {
        self.id = id
        self.token = token
        self.$user.id = userID
    }
    
}

extension UserToken: ModelUserToken {
    public var isValid: Bool {
        return true
    }
    
    public static let valueKey = \UserToken.$token
    public static let userKey = \UserToken.$user
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
