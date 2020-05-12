//
//  User.swift
//  App
//
//  Created by Oguz Sutanrikulu on 19.01.20.
//

import Vapor
import Fluent

///LI.CO.RE's persistable user class which is used for authentication.
///This class contains the user's 'name', and 'email'.
public final class LicoreUser: Content, Model, ModelSessionAuthenticatable {
    
    public static var schema: String = "users"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Field(key: "name")
    public var name: String
    
    @Field(key: "email")
    public var email: String
    
    @Field(key: "password_hash")
    var passwordHash: String
    
    func generateToken() throws -> UserToken {
        try .init(token: [UInt8].random(count: 16).base64, userID: self.requireID())
    }
    
    public init() { }
    
    init(id: Int? = nil, name: String, email: String, passwordHash: String) {
        self.id = id
        self.name = name
        self.email = email
        self.passwordHash = passwordHash
    }
    
}

extension LicoreUser: ModelAuthenticatable {
    public static let usernameKey = \LicoreUser.$name
    public static let passwordHashKey = \LicoreUser.$passwordHash

    public func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}

extension LicoreUser {
    struct LicoreUserMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .field("id", .int, .identifier(auto: true))
                .field("name", .string, .required)
                .field("email", .string, .required)
                .field("password_hash", .string, .required)
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users").delete()
        }
    }
}
