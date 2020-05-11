//
//  GitHubRepositoryResponse.swift
//  App
//
//  Created by Oguz Sutanrikulu on 18.12.19.
//

import Vapor

struct GitHubRepositoryResponse: Content {
    let id: Int
    let name: String
    
    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
    }
    
}

struct GitHubOrganizationResponse: Content {
    let id: Int
    let key: String
    
    init(id: Int, key: String) {
        self.id = id
        self.key = key
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case key = "login"
    }
}

extension GitHubRepositoryResponse: LicoreModelConvertable {
    func createLicoreModel() -> Repository {
        return Repository(scmId: id, name: self.name, projectID: 0)
    }
}
