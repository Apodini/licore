//
//  GitHubReview.swift
//  App
//
//  Created by Oguz Sutanrikulu on 25.03.20.
//

import Vapor
import SwiftLintFramework

class GitHubReview: Reviewable {
    
    func runReview(project: LicoreProject, repository: Repository, pullRequest: PullRequest, req: Request) {
        logger.info("Review process started...")
        
        let shortHash = String(pullRequest.latestCommit.prefix(8))
        let swiftLint = SwiftLint()
        
        if self.directoryExists(pullRequest: pullRequest) {
            logger.info("Deleting existing directory...")
            self.deleteDirectory(pullRequest: pullRequest)
        }
        
        project.sourceControlService(req: req).map { sourceControlService in
            
            guard let sourceControlService = sourceControlService else {
                logger.error("Source Control Service could not be loaded!")
                return
            }
            
            logger.info("Deleting older Comments...")
            sourceControlService.deleteAllComments(repositoryName: repository.name, pullRequestId: pullRequest.scmId, req: req)
            
            logger.info("Creating new directory...")
            self.createDirectory(pullRequest: pullRequest)
            
            logger.info("Downloading sources...")
            sourceControlService.downloadSources(pullRequest: pullRequest, req: req) {
                
                logger.info("Unzipping...")
                self.unzipSources(fileName: "sourceFiles", fileExtension: ".zip", pullRequest: pullRequest)
                
                logger.info("Linting...")
                let violations = swiftLint.runLinting(for: shortHash, with: project.rules)
                var comments: ([StyleViolation], [(StyleViolation, Segment)])?
                
                logger.info("Getting the Diff...")
                sourceControlService.getDiff(repositoryName: repository.name, pullRequestId: pullRequest.scmId, req: req).whenSuccess { diff in
                    comments = self.getCommentMetaData(violations: violations, diff: diff, onlyAddedLines: true)
                    
                    guard let generalComments = comments?.0 else {
                        logger.warning("No General Comments were generated!")
                        return
                    }
                    guard let inlineComments = comments?.1 else {
                        logger.warning("No Inline Comments were generated!")
                        return
                    }
                    
                    logger.info("General Comments: \(generalComments.count)")
                    logger.info("Inline Comments: \(inlineComments.count)")
                    
                    logger.info("Posting Inline Comments...")
                    for inlineComment in inlineComments {
                        let comment = Comment(id: nil,
                                              line: inlineComment.0.location.line!,
                                              lineType: inlineComment.1.type,
                                              ruleDescription: inlineComment.0.ruleName,
                                              content: inlineComment.0.reason,
                                              path: String(inlineComment.0.location.relativeFile?.split(separator: "/",
                                                                                                        maxSplits: 1,
                                                                                                        omittingEmptySubsequences: true)[1] ?? ""),
                                              type: CommentType(rawValue: inlineComment.0.severity.rawValue))
                        
                        sourceControlService.postComment(repositoryName: repository.name,
                                                         pullRequest: pullRequest,
                                                         comment: comment,
                                                         diff: diff,
                                                         req: req)
                    }
                    
                    var comments: [Comment] = []
                    
                    logger.info("Aggregating General Comments...")
                    for generalComment in generalComments {
                        comments.append(Comment(id: nil,
                                                line: nil,
                                                lineType: "",
                                                ruleDescription: generalComment.ruleDescription,
                                                content: generalComment.reason,
                                                path: "",
                                                type: CommentType(rawValue: generalComment.severity.rawValue)))
                    }
                    
                    if !comments.isEmpty {
                        logger.info("Posting General Comments...")
                        sourceControlService.postGeneralComment(repositoryName: repository.name,
                                                                pullRequest: pullRequest,
                                                                comments: comments,
                                                                req: req)
                    }
                    
                    if generalComments.isEmpty && inlineComments.isEmpty {
                        logger.info("Approving Pull Request...")
                        sourceControlService.approvePullRequest(repositoryName: repository.name, pullRequest: pullRequest, req: req)
                    } else {
                        logger.info("Pull Request Needs Work...")
                        sourceControlService.markNeedsRework(repositoryName: repository.name, pullRequest: pullRequest, req: req).whenSuccess { _ in
                            logger.info("Generating Tasks...")
                            let newTasks = self.generateTasks(for: violations)
                            
                            logger.info("Posting Tasks...")
                            sourceControlService.postTasks(repositoryName: repository.name,
                                                           pullRequest: pullRequest,
                                                           tasks: newTasks,
                                                           req: req).whenSuccess { status in
                                logger.info("Deleting Sourcefolder...")
                                self.deleteDirectory(pullRequest: pullRequest)
                                
                                logger.info("Generating Review Statistics...")
                                let reviewStatistics = self.generateResult(for: violations)
                                
                                RepositoryDeveloper.query(on: req.db).with(\.$repository).with(\.$developer).all().map { repositoryDevelopers in
                                    let developerFiltered = repositoryDevelopers.filter { $0.$repository.id == repository.id }.map { $0.developer }
                                    guard let developerID = developerFiltered.first?.id else {
                                        logger.warning("Developer not found!")
                                        return
                                    }
                                    
                                    logger.info("Saving Review Statistics...")
                                    ReviewStatistics(violations: reviewStatistics,
                                                     developerID: developerID).save(on: req.db)
                                    
                                }.whenSuccess {
                                    ReviewJobData.query(on: req.db).with(\.$pullRequest).all().map { jobs in
                                        let jobFiltered = jobs.filter { $0.$pullRequest.id == pullRequest.id }
                                        guard let job = jobFiltered.first else {
                                            logger.warning("Review Job not found!")
                                            return
                                        }
                                        
                                        logger.info("Setting Job Status...")
                                        job.status = .done
                                        job.update(on: req.db).map {
                                            logger.info("Reviewer Job ended successful!")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
