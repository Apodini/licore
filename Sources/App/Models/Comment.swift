//
//  Comment.swift
//  App
//
//  Created by Oguz Sutanrikulu on 17.12.19.
//

import Vapor

//Defines the type of the 'Comment' posted by LI.CO.RE.
public enum CommentType: String, Codable {
    case warning
    case error
    case message
}

//LI.CO.RE's representation of a 'Comment'.
//It contains all information neccessary to post it as an inline 'Comment' to the respective source control management system.
public final class Comment: Content {
    
    public var id: Int?
    public var version: Int?
    public var line: Int?
    public var lineType: String?
    public var ruleDescription: String
    public var content: String
    public var path: String?
    public var type: CommentType?
    
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
