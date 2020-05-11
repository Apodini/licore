//
//  LicoreModelConvertable.swift
//  App
//
//  Created by Oguz Sutanrikulu on 17.12.19.
//

import Vapor

protocol LicoreModelConvertable {
    associatedtype ReturnLicoreModel
    func createLicoreModel() -> ReturnLicoreModel
}
