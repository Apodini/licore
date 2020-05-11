//
//  GitHubDiffResponse.swift
//  App
//
//  Created by Oguz Sutanrikulu on 22.03.20.
//

import Vapor

struct GitHubDiffResponse: Content {
    let files: [GitHubFiles]

    init(files: [GitHubFiles]) {
        self.files = files
    }
    
    private enum CodingKeys: String, CodingKey {
        case files
    }
}

struct GitHubFiles: Content {
    let filename: String
    
    init(filename: String) {
        self.filename = filename
    }
    
    private enum CodingKeys: String, CodingKey {
        case filename
    }
}

extension GitHubDiffResponse: LicoreModelConvertable {
    func createLicoreModel() -> Diff {
        return Diff(fromRef: "",
                    toRef: "",
                    diffs: files.map {
                        Diffs(destination: Destination(toString: $0.filename),
                              hunks: nil)
                    }
        )
    }
}
