//
//  Task.swift
//  App
//
//  Created by Oguz Sutanrikulu on 11.01.20.
//

import Vapor

final class Task: Content {
    
    var id: Int?
    var description: String
    var occurence: Int
    var resolved: Bool
    
    init(id: Int? = nil, description: String, occurence: Int, resolved: Bool = false) {
        self.id = id
        self.description = description
        self.occurence = occurence
        self.resolved = resolved
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case description
        case occurence
        case resolved
    }
    
}
