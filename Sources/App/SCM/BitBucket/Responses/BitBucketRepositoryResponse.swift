//
//  BitBucketRepositoryResponse.swift
//  App
//
//  Created by Oguz Sutanrikulu on 16.12.19.
//

import Vapor

struct BitBucketRepositoryResponse: Content {
    let id: Int
    let slug: String
    let project: BitBucketProject
    
    init(id: Int, slug: String, project: BitBucketProject) {
        self.id = id
        self.slug = slug
        self.project = project
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case slug
        case project
    }
}

struct BitBucketProject: Content {
    let id: Int
    let key: String
    
    init(id: Int, key: String) {
        self.id = id
        self.key = key
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case key
    }
}

extension BitBucketRepositoryResponse: LicoreModelConvertable {
    func createLicoreModel() -> Repository {
        return Repository(scmId: id, name: slug, projectID: project.id)
    }
}
