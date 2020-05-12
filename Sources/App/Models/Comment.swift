//
//  Comment.swift
//  App
//
//  Created by Oguz Sutanrikulu on 17.12.19.
//

import Vapor

public enum CommentType: String, Codable {
    case warning
    case error
    case message
}

public final class Comment: Content {
    
    var id: Int?
    var version: Int?
    var line: Int?
    var lineType: String?
    var ruleDescription: String
    var content: String
    var path: String?
    var type: CommentType?
    
    init(id: Int?, version: Int? = nil, line: Int?, lineType: String?, ruleDescription: String, content: String, path: String?, type: CommentType?) {
        self.id = id
        self.version = version
        self.line = line
        self.lineType = lineType
        self.ruleDescription = ruleDescription
        self.content = content
        self.path = path
        self.type = type
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case version
        case line
        case lineType
        case ruleDescription
        case content
        case path
        case type
    }
    
}

extension Comment {
    var violationIcon: String {
        switch type {
        case .error:
            return "🚫"
        case .warning:
            return "⚠️"
        default:
            return "📖"
        }
    }
    
    var violationTypeName: String {
        switch type {
        case .error:
            return "Error"
        case .warning:
            return "Warning"
        default:
            return "Message"
        }
    }
}
