//
//  BitBucketDiffResponse.swift
//  App
//
//  Created by Oguz Sutanrikulu on 06.01.20.
//

import Vapor

struct BitBucketDiffResponse: Content {
    let fromHash: String
    let toHash: String
    let diffs: [Diffs]
    
    init(fromHash: String, toHash: String, diffs: [Diffs]) {
        self.fromHash = fromHash
        self.toHash = toHash
        self.diffs = diffs
    }
    
    private enum CodingKeys: String, CodingKey {
        case fromHash
        case toHash
        case diffs
    }
}

extension BitBucketDiffResponse: LicoreModelConvertable {
    func createLicoreModel() -> Diff {
        return Diff(fromRef: self.fromHash, toRef: self.toHash, diffs: self.diffs)
    }
}
