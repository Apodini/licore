//
//  ReviewStatistics.swift
//  App
//
//  Created by Oguz Sutanrikulu on 14.02.20.
//

import Vapor
import Fluent

///A persistable class holding the 'violations' from a review job.
///It has a parent relation to a 'Developer'.
public final class ReviewStatistics: Content, Model {
    
    public static var schema: String = "reviewstatistics"
    
    @ID(custom: "id")
    public var id: Int?
    
    @Field(key: "violations")
    public var violations: [String: Int]
    
    @Parent(key: "developer_id")
    public var developer: Developer
    
    public init() { }
    
    init(id: Int? = nil, violations: [String: Int], developerID: Developer.IDValue) {
        self.id = id
        self.violations = violations
        self.$developer.id = developerID
    }
    
}

extension ReviewStatistics {
    struct ReviewStatisticsMigration: Fluent.Migration {
        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("reviewstatistics")
                .field("id", .int, .identifier(auto: true))
                .field("violations", .json, .required)
                .field("developer_id", .int, .references("developers", "id", onDelete: .cascade, onUpdate: .cascade))
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("reviewstatistics").delete()
        }
    }
    
    var sumViolations: Int {
        return violations.compactMap { $0.value }.reduce(0, +)
    }
}
