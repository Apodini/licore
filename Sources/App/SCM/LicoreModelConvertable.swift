//
//  LicoreModelConvertable.swift
//  App
//
//  Created by Oguz Sutanrikulu on 17.12.19.
//

import Vapor

///A common interface for converting objects from external sources into a LI.CO.RE model.
public protocol LicoreModelConvertable {
    associatedtype ReturnLicoreModel
    func createLicoreModel() -> ReturnLicoreModel
}
