//
//  WebhooksController+BitBucket.swift
//  App
//
//  Created by Oguz Sutanrikulu on 05.01.20.
//

import Vapor
import Queues


extension WebhooksController {
    func addToQueue(req: Request, webhookContent: BitBucketWebhookResponse) -> EventLoopFuture<HTTPStatus> {
        logger.info("\(req.content)")
        
        switch webhookContent.eventKey {
        case "pr:opened":
            logger.info("Pull Request Opened...")
            
            guard let pullRequest = webhookContent.pullRequest?.createLicoreModel() else {
                logger.warning("Webhook Content: Pull Request not found!")
                return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Webhook Content: Pull Request not found!"))
            }
            guard let projectKey = webhookContent.pullRequest?.fromRef.repository.project.key else {
                logger.warning("Webhook Content: Project Key not found!")
                return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Webhook Content: Project Key not found!"))
            }
            guard let repository = webhookContent.pullRequest?.fromRef.repository else {
                logger.warning("Webhook Content: Pull Request not found!")
                return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Webhook Content: Pull Request not found!"))
            }
            
            return Repository
                .query(on: req.db)
                .all()
                .flatMap { repositories -> EventLoopFuture<Void> in
                    guard let repositoryID = repositories
                            .first(where: { $0.project.key == repository.project.key && $0.scmId == repository.id })?
                            .id else {
                        logger.warning("Webhook Content: Repository ID \(repository.id) unknown!")
                        return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Webhook Content: Repository ID \(repository.id) unknown!"))
                    }
                    
                    pullRequest.$repository.id = repositoryID
                    
                    return pullRequest
                        .save(on: req.db)
                }
                .flatMap {
                    // Check if the project exists
                    LicoreProject
                        .query(on: req.db)
                        .filter(\LicoreProject.$key, .equal, projectKey)
                        .first()
                }
                .flatMap { _ in
                    guard let pullRequestID = pullRequest.id else {
                        logger.warning("Webhook Content: Pull Request ID \(String(describing: pullRequest.id)) unknown!")
                        return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Webhook Content: Pull Request ID \(String(describing: pullRequest.id)) unknown!"))
                    }
                    
                    let jobData = ReviewJobData(pullRequestID: pullRequestID)
                    return jobData
                        .save(on: req.db)
                        .flatMap {
                            req.queue.dispatch(ReviewJob.self, jobData)
                        }
                }
                .map {
                    HTTPStatus.ok
                }
        case "repo:refs_changed":
            logger.info("Refs Changed...")
            
            guard let changes = webhookContent.changes else {
                logger.warning("Webhook Content: No Changes found!")
                return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Webhook Content: No Changes found!"))
            }
            guard let repository = webhookContent.repository else {
                logger.warning("Webhook Content: Repository not found!")
                return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Webhook Content: Repository not found!"))
            }
            guard let change = changes.first else {
                logger.warning("Webhook Content: No Change found!")
                return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Webhook Content: No Change found!"))
            }
            
            if change.type == "ADD" {
                logger.info("...with Change Type 'ADD'")
                
                return Repository
                    .query(on: req.db)
                    .with(\.$project).all()
                    .flatMap { repositories in
                        guard let repositoryID = repositories
                                .first(where: { $0.project.key == repository.project.key && $0.scmId == repository.id })?
                                .id else {
                            logger.warning("Webhook Content: Repository ID \(repository.id) unknown!")
                            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Webhook Content: Repository ID \(repository.id) unknown!"))
                        }
                        
                        guard let date = ISO8601DateFormatter().date(from: webhookContent.date) else {
                            logger.warning("Creation Date could not be formatted to ISO860!")
                            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Creation Date could not be formatted to ISO860!"))
                        }
                        let interval = date.timeIntervalSince1970
                        
                        return Branch(creationDate: interval, refId: change.refId, repositoryID: repositoryID)
                            .save(on: req.db)
                    }
                    .map {
                        HTTPStatus.ok
                    }
            } else {
                return LicoreProject
                    .query(on: req.db)
                    .filter(\LicoreProject.$key, .equal, repository.project.key)
                    .first()
                    .flatMap { project -> EventLoopFuture<SourceControlServable?> in
                        guard let project = project else {
                            logger.warning("Project not found!")
                            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Project not found!"))
                        }
                        
                        return project.sourceControlService(req: req)
                    }
                    .flatMap { sourceControlService -> EventLoopFuture<[PullRequest]> in
                        guard let sourceControlService = sourceControlService else {
                            logger.error("Source Control Service could not be loaded!")
                            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Source Control Service could not be loaded!"))
                        }
                        
                        return sourceControlService.getPullRequests(repositoryName: repository.slug, req: req)
                    }
                    .flatMap { pullRequests -> EventLoopFuture<HTTPStatus> in
                        guard let pullRequest = pullRequests.first(where: { $0.refId == change.refId }) else {
                            logger.warning("Pull Request not found! ... creating a new PR in the database")
                            let newWebhookContent = BitBucketWebhookResponse(eventKey: "pr:opened",
                                                                             date: webhookContent.date,
                                                                             pullRequest: webhookContent.pullRequest,
                                                                             repository: webhookContent.repository,
                                                                             changes: webhookContent.changes,
                                                                             previousStatus: webhookContent.previousStatus)
                            return self.addToQueue(req: req, webhookContent: newWebhookContent)
                        }
                        
                        return PullRequest
                            .query(on: req.db)
                            .with(\.$repository)
                            .all()
                            .flatMap { allPullRequests -> EventLoopFuture<Void> in
                                let currentRepoPullRequests = allPullRequests.filter {
                                    $0.repository.name == repository.slug
                                }
                                
                                guard let currentPullRequest = currentRepoPullRequests.first(where: {$0.scmId == pullRequest.scmId }) else {
                                    logger.warning("Pull Request not matched with database!")
                                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Pull Request not matched with database!"))
                                }
                                
                                currentPullRequest.latestCommit = pullRequest.latestCommit
                                return currentPullRequest
                                    .update(on: req.db)
                                    .flatMap { _ in
                                        guard let currentPullRequestID = currentPullRequest.id else {
                                            logger.warning("Pull Request ID not in database!")
                                            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Pull Request ID not in database!"))
                                        }
                                        
                                        let jobData = ReviewJobData(pullRequestID: currentPullRequestID)
                                        return jobData
                                            .save(on: req.db)
                                            .flatMap {
                                                req.queue.dispatch(ReviewJob.self, jobData)
                                            }
                                    }
                            }
                            .map {
                                HTTPStatus.ok
                            }
                    }
            }
        case "pr:reviewer:approved", "pr:reviewer:needs_work":
            logger.info("Pull Request Approved...")
            
            guard let approvedPullRequest = webhookContent.pullRequest else {
                logger.warning("Approved Pull Request not found!")
                return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Approved Pull Request not found!"))
            }
            guard let previousStatus = webhookContent.previousStatus else {
                logger.warning("Previous Pull Request Status not found!")
                return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Previous Pull Request Status not found!"))
            }
            
            return PullRequest
                .query(on: req.db)
                .all()
                .flatMap { pullRequests in
                    guard let pullRequestID = pullRequests.first(where: { $0.scmId == approvedPullRequest.id })?.id else {
                        logger.warning("Pull Request ID not found!")
                        return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Pull Request ID not found!"))
                    }
                    
                    guard let date = ISO8601DateFormatter().date(from: webhookContent.date) else {
                        logger.warning("Creation Date could not be formatted to ISO860!")
                        return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Creation Date could not be formatted to ISO860!"))
                    }
                    let interval = date.timeIntervalSince1970
                    
                    return StatusChange(previousStatus: previousStatus, newStatus: .approved, date: interval, pullRequestID: pullRequestID)
                        .save(on: req.db)
                }
                .map {
                    HTTPStatus.ok
                }
        default:
            logger.warning("Bitbucket Event Key not matched...")
            return req.eventLoop.future(HTTPStatus.init(statusCode: 500))
        }
    }
}
