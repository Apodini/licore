//
//  BitBucketParticipantsResponse.swift
//  App
//
//  Created by Oguz Sutanrikulu on 09.02.20.
//

import Vapor

struct BitBucketParticipantsResponse: Content {
    let displayName: String
    let slug: String
    let emailAddress: String
    
    init(displayName: String, slug: String, emailAddress: String) {
        self.displayName = displayName
        self.slug = slug
        self.emailAddress = emailAddress
    }
    
    private enum CodingKeys: String, CodingKey {
        case displayName
        case slug
        case emailAddress
    }
}

struct BitBucketUserResponse: Content {
    let user: BitBucketParticipantsResponse
    
    init(user: BitBucketParticipantsResponse) {
        self.user = user
    }
    
    private enum CodingKeys: String, CodingKey {
        case user
    }
}

extension BitBucketParticipantsResponse: LicoreModelConvertable {
    func createLicoreModel() -> Developer {
        return Developer(slug: slug, name: displayName, email: emailAddress)
    }
}
