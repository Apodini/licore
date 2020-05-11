//
//  BitBucketTasksResponse.swift
//  App
//
//  Created by Oguz Sutanrikulu on 28.01.20.
//

import Vapor

struct Values: Content {
    let id: Int?
    let text: String?
    let state: String?
    let author: BitBucketAuthorResponse?
    
    init(id: Int?, text: String?, state: String?, author: BitBucketAuthorResponse?) {
        self.id = id
        self.text = text
        self.state = state
        self.author = author
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case state
        case author
    }
}

struct BitBucketTasksResponse: Content {
    let values: [Values]?
    
    init(values: [Values]?) {
        self.values = values
    }
    
    private enum CodingKeys: String, CodingKey {
        case values
    }
}

extension Values: LicoreModelConvertable {
    typealias ReturnLicoreModel = Task?
    
    func createLicoreModel() -> Task? {
        guard let text = text else { return nil }
        
        return Task(id: id,
                    description: text,
                    occurence: 0,
                    resolved: state == "RESOLVED" ? true : false)
    }
}
