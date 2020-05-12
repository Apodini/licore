//
//  SwiftLint.swift
//  App
//
//  Created by Oguz Sutanrikulu on 30.12.19.
//

import Vapor
import SwiftLintFramework

///A wrapper class around SwiftLint's swift interface.
public class SwiftLint {
    
    public func getFilePaths(at shortHash: String) -> [String] {
        let fileManager = FileManager()
        let dirs = DirectoryConfiguration.self
        let workDirPath = dirs.detect().workingDirectory
        
        logger.info("Getting File Paths: \(workDirPath)")
        
        var filePaths: [String] = []
        
        let directoryEnumerator: FileManager.DirectoryEnumerator? = fileManager.enumerator(atPath: "\(workDirPath)sources_" + shortHash)
        while let path = directoryEnumerator?.nextObject() as? String {
            if path.hasSuffix("swift") {
                filePaths.append("\(workDirPath)sources_" + shortHash + "/" + path)
            }
        }
        return filePaths
    }
    
    public func createSwiftLintFile(for paths: [String]) -> [SwiftLintFile] {
        var files: [SwiftLintFile] = []
        
        for path in paths {
            guard let swiftLintFile = SwiftLintFile(path: path) else { continue }
            files.append(swiftLintFile)
        }
        logger.info("Lint Files Count: \(files.count)")
        return files
    }
    
    public func configFileExists(at shortHash: String) -> Bool {
        let fileManager = FileManager()
        let dirs = DirectoryConfiguration.self
        let workDirPath = dirs.detect().workingDirectory
        
        if workDirPath.isEmpty || !fileManager.fileExists(atPath: "\(workDirPath)sources_" + shortHash + "/" + ".swiftlint.yml") {
            logger.warning("Config file .swiftlint.yml not found or directory empty at: ")
            logger.warning("\(workDirPath)sources_\(shortHash)")
            
            return false
        }
        
        logger.warning("Using .swiftlint.yml at: \(workDirPath)sources_\(shortHash)")
        return true
    }
    
    public func runLinting(for shortHash: String, with rules: String) -> [StyleViolation] {
        let storage = RuleStorage()
        
        let dirs = DirectoryConfiguration.self
        let workDirPath = dirs.detect().workingDirectory
        
        let filePaths = getFilePaths(at: shortHash)
        let lintFiles = createSwiftLintFile(for: filePaths)
        
        var violations: [StyleViolation] = []
        
        if configFileExists(at: shortHash) {
            logger.info("Config file exists!")
            let config = Configuration(path: "\(workDirPath)sources_" + shortHash + "/" + ".swiftlint.yml")
            
            for lintFile in lintFiles {
                violations.append(contentsOf: Linter(file: lintFile, configuration: config).collect(into: storage).styleViolations(using: storage))
            }
            
            return violations
        }
        
        logger.warning("Config file does not exist!")
        do {
            let dict = try YamlParser.parse(rules)
            
            if dict.isEmpty {
                logger.warning("No rules configured!")
                logger.warning("Loading Rules from LI.CO.RE default file...")
                let config = Configuration(path: "\(workDirPath)" + ".swiftlint.yml")
                
                for lintFile in lintFiles {
                    violations.append(contentsOf: Linter(file: lintFile,
                                                         configuration: config).collect(into: storage).styleViolations(using: storage))
                }
            }
            
            if let config = Configuration(dict: dict) {
                logger.warning("Loading Config from Database...")
                for lintFile in lintFiles {
                    violations.append(contentsOf: Linter(file: lintFile,
                                                         configuration: config).collect(into: storage).styleViolations(using: storage))
                }
            }
        } catch {
            logger.warning("Rules Parsing Failed!")
        }
        
        return violations
    }
}
