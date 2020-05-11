//
//  Diff.swift
//  App
//
//  Created by Oguz Sutanrikulu on 06.01.20.
//

import Vapor

final class Diff: Content {
    
    var fromRef: String
    var toRef: String
    var diffs: [Diffs]
    
    init(fromRef: String, toRef: String, diffs: [Diffs]) {
        self.fromRef = fromRef
        self.toRef = toRef
        self.diffs = diffs
    }
    
    private enum CodingKeys: String, CodingKey {
        case fromRef
        case toRef
        case diffs
    }
    
}

struct Diffs: Content {
    var destination: Destination?
    var hunks: [Hunk]?
    
    init(destination: Destination?, hunks: [Hunk]?) {
        self.destination = destination
        self.hunks = hunks
    }
    
    private enum CodingKeys: String, CodingKey {
        case destination
        case hunks
    }
}

struct Destination: Content {
    var toString: String?
    
    init(toString: String) {
        self.toString = toString
    }
    
    private enum CodingKeys: String, CodingKey {
        case toString
    }
}

struct Hunk: Content {
    var destinationLine: Int?
    var destinationSpan: Int?
    var segments: [Segment]?
    
    init(destinationLine: Int?, destinationSpan: Int?, segments: [Segment]?) {
        self.destinationLine = destinationLine
        self.destinationSpan = destinationSpan
        self.segments = segments
    }
    
    private enum CodingKeys: String, CodingKey {
        case destinationLine
        case destinationSpan
        case segments
    }
}

struct Segment: Content {
    var type: String?
    var lines: [Line]?
    
    init(type: String?, lines: [Line]?) {
        self.type = type
        self.lines = lines
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case lines
    }
}

struct Line: Content {
    var line: String?
    var destination: Int?
    
    init(line: String?, destination: Int?) {
        self.line = line
        self.destination = destination
    }
    
    private enum CodingKeys: String, CodingKey {
        case line
        case destination
    }
}
