//
//  SourceControlType.swift
//  App
//
//  Created by Oguz Sutanrikulu on 31.01.20.
//

import Vapor

//An enum representation of the currently supported source control management systems.
public enum SourceControlType: String, Codable {
    case bitbucket
    case github
}
