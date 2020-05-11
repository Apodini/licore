//
//  Reviewable.swift
//  App
//
//  Created by Oguz Sutanrikulu on 25.03.20.
//

import Vapor
import SwiftLintFramework

protocol Reviewable {
    func runReview(project: LicoreProject, repository: Repository, pullRequest: PullRequest, req: Request)
}

extension Reviewable {
    
    func deleteDirectory(pullRequest: PullRequest) {
        let dirs = DirectoryConfiguration.self
        let path = dirs.detect().workingDirectory
        let fileManager = FileManager()
        
        let shortHash = pullRequest.latestCommit.prefix(8)
        
        do {
            logger.info("Deleting directory: sources_\(shortHash)")
            try fileManager.removeItem(atPath: path + "sources_" + shortHash)
        } catch {
            logger.info("\(error.localizedDescription)")
        }
    }
    
    func directoryExists(pullRequest: PullRequest) -> Bool {
        let dirs = DirectoryConfiguration.self
        let path = dirs.detect().workingDirectory
        let fileManager = FileManager()
        
        let shortHash = pullRequest.latestCommit.prefix(8)
        
        let directoryExists = fileManager.fileExists(atPath: path + "sources_" + shortHash)
        logger.info("Directory exists: \(directoryExists.description)")
        
        return directoryExists
    }
    
    func createDirectory(pullRequest: PullRequest) {
        let dirs = DirectoryConfiguration.self
        let path = dirs.detect().workingDirectory
        let fileManager = FileManager()
        
        let shortHash = pullRequest.latestCommit.prefix(8)
        
        do {
            logger.info("Creating directory: sources_\(shortHash)")
            try fileManager.createDirectory(atPath: path + "sources_" + shortHash, withIntermediateDirectories: false, attributes: nil)
        } catch {
            logger.info("\(error.localizedDescription)")
        }
    }
    
    func unzipSources(fileName: String, fileExtension: String, pullRequest: PullRequest) {
        let dirs = DirectoryConfiguration.self
        let path = dirs.detect().workingDirectory
        let fileManager = FileManager()
        
        let shortHash = pullRequest.latestCommit.prefix(8)
        
        do {
            logger.info("Unzip sources...")
            try fileManager.unzipItem(at: URL(fileURLWithPath: path + "sources_" + shortHash + "/" + fileName + fileExtension),
                                      to: URL(fileURLWithPath: path + "sources_" + shortHash))
        } catch {
            logger.info("\(error.localizedDescription)")
        }
    }
    
    func generateTasks(for violations: [StyleViolation]) -> [Task] {
        let ruleDescriptionNames = violations.map { violation in
            violation.ruleName
        }
        
        let repeatedElements = repeatElement(1, count: ruleDescriptionNames.count)
        
        let tasksDictionary = Dictionary(zip(ruleDescriptionNames, repeatedElements), uniquingKeysWith: +)
        
        return tasksDictionary.map { task in
            return Task(description: task.key, occurence: task.value)
        }
    }
    
    func generateResult(for violations: [StyleViolation]) -> [String: Int] {
        let ruleDescriptionNames = violations.map { violation in
            violation.ruleName
        }
        
        let repeatedElements = repeatElement(1, count: ruleDescriptionNames.count)
        
        let resultDictionary = Dictionary(zip(ruleDescriptionNames, repeatedElements), uniquingKeysWith: +)
        
        return resultDictionary
    }
    
    func getCommentMetaData(violations: [StyleViolation],
                            diff: Diff,
                            onlyAddedLines: Bool = false) -> ([StyleViolation], [(StyleViolation, Segment)]) {
        let diffFiles = diff.diffs
        
        var generalViolations: [StyleViolation] = []
        var inlineFindings: [(StyleViolation, Segment)] = []
        
        violations.forEach { violation in
            guard let line = violation.location.line else { return }
            
            let matchingFile = diffFiles.first { diffFile in
                guard let substring = diffFile.destination?.toString else { return false }
                let string = violation.location.file
                return string?.contains(substring) ?? false
            }
            
            guard matchingFile != nil else { return generalViolations.append(violation) }
            
            let matchingHunk = matchingFile?.hunks?.first { hunk in
                let firstLine = hunk.destinationLine
                let lastLine = hunk.destinationLine! + hunk.destinationSpan! - 1
                return line >= firstLine! && line <= lastLine
            }
            
            guard matchingHunk != nil else { return generalViolations.append(violation) }
            
            let matchingSegment = matchingHunk?.segments!.filter { segment in
                !onlyAddedLines || segment.type == "ADDED"
            }.first { seg in
                seg.lines!.contains { currentLine in
                    currentLine.destination == line
                }
            }
            
            guard matchingSegment != nil else { return generalViolations.append(violation) }
            
            inlineFindings.append((violation, matchingSegment!))
            
        }
        return (generalViolations, inlineFindings)
    }
    
}
