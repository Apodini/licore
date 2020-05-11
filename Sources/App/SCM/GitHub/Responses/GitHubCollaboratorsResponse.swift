//
//  GitHubCollaboratorsResponse.swift
//  App
//
//  Created by Oguz Sutanrikulu on 27.03.20.
//

import Vapor

struct GitHubCollaboratorsResponse: Content {
    let login: String
    
    init(login: String) {
        self.login = login
    }
    
    private enum CodingKeys: String, CodingKey {
        case login
    }
}

extension GitHubCollaboratorsResponse: LicoreModelConvertable {
    func createLicoreModel() -> Developer {
        return Developer(slug: login, name: "", email: "")
    }
}
