//
//  WebhooksController+GitHub.swift
//  App
//
//  Created by Oguz Sutanrikulu on 05.01.20.
//

import Vapor
import Queues


extension WebhooksController {
    func addToQueue(req: Request, webhookContent: GitHubWebhookResponse) -> EventLoopFuture<HTTPStatus> {
        logger.info("\(req.content)")
        
        switch webhookContent.eventKey {
        case "pull_request":
            
            guard webhookContent.action == "opened" || webhookContent.action == "synchronize" else {
                logger.info("Key 'action' is not 'opened'!")
                return req.eventLoop.future(.notFound)
            }
            
            logger.info("Pull Request Opened...")
            
            guard let pullRequest = webhookContent.pullRequest?.createLicoreModel() else {
                logger.warning("Webhook Content: Pull Request not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            guard let projectKey = webhookContent.organization?.key else {
                logger.warning("Webhook Content: Project Key not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            guard let repository = webhookContent.repository else {
                logger.warning("Webhook Content: Pull Request not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            
            Repository.query(on: req.db).all().whenSuccess { repositories in
                let repo = repositories.filter { $0.scmId == repository.id }.first
                guard let repoID = repo?.id else {
                    logger.warning("Webhook Content: Repository ID \(repository.id) unknown!")
                    return
                }
                pullRequest.$repository.id = repoID
                LicoreProject.query(on: req.db).filter(\LicoreProject.$key, .equal, projectKey).first().map { _ in
                    pullRequest.save(on: req.db).whenSuccess { _ in
                        PullRequest.query(on: req.db).all().map { pullRequests in
                            let persistedPullRequest = pullRequests.filter { $0.scmId == pullRequest.scmId }
                            
                            guard let pullRequestID = persistedPullRequest.first?.id else {
                                logger.warning("Webhook Content: Pull Request ID \(String(describing: pullRequest.id)) unknown!")
                                return
                            }
                            
                            let jobData = ReviewJobData(pullRequestID: pullRequestID)
                            jobData.save(on: req.db).whenSuccess {
                                req.queue.dispatch(ReviewJob.self, jobData)
                            }
                        }
                    }
                }
            }
            return req.eventLoop.makeSucceededFuture(HTTPStatus.ok)
            
        case "create":
            logger.info("New Branch Created...")
            
            guard let ref = webhookContent.ref else {
                logger.warning("Webhook Content: Ref not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            
            guard let repository = webhookContent.repository else {
                logger.warning("Webhook Content: Repository not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            
            guard let project = webhookContent.organization else {
                logger.warning("Webhook Content: Project not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            
            Repository.query(on: req.db).with(\.$project).all().map { repositories in
                let repos = repositories.filter { $0.project.key == project.key && $0.scmId == repository.id }
                
                guard let repoID = repos.first?.id else {
                    logger.warning("Webhook Content: Repository ID \(repository.id) unknown!")
                    return
                }
                
                let interval = Date().timeIntervalSince1970.rounded(.down)
                
                Branch(creationDate: interval, refId: ref, repositoryID: repoID).save(on: req.db)
            }
            
        case "push":
            logger.info("New Commit Pushed...")
            
            guard let ref = webhookContent.ref else {
                logger.warning("Webhook Content: Ref not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            
            guard let repository = webhookContent.repository else {
                logger.warning("Webhook Content: Repository not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            
            guard let project = webhookContent.organization else {
                logger.warning("Webhook Content: Project not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            
            LicoreProject.query(on: req.db).filter(\LicoreProject.$key, .equal, project.key).first().map { project in
                var pullRequest: PullRequest?
                
                guard let project = project else {
                    logger.warning("Project not found!")
                    return
                }
                
                project.sourceControlService(req: req).whenSuccess {
                    
                    guard let sourceControlService = $0 else {
                        logger.error("Source Control Service could not be loaded!")
                        return
                    }
                    
                    sourceControlService.getPullRequests(repositoryName: repository.name, req: req).whenSuccess { pullRequests in
                        
                        pullRequests.first { preq in
                            guard let refId = preq.refId else {
                                logger.warning("Ref ID not found!")
                                return false
                            }
                            
                            return refId == ref
                        }.map { matchedPR in
                            pullRequest = matchedPR
                        }
                        
                        guard let pullRequestID = pullRequest?.$scmId.value else {
                            logger.warning("Pull Request not found!")
                            return
                        }
                        
                        ReviewJobData.query(on: req.db).with(\.$pullRequest).all().map { allJobData in
                            let job = allJobData.filter { $0.pullRequest.scmId == pullRequestID }.first
                            
                            guard let jobData = job else {
                                logger.info("Review Job not found!")
                                return
                            }
                            
                            req.queue.dispatch(ReviewJob.self, jobData)
                        }
                    }
                }
            }
            
        default:
            logger.warning("GitHub Event Key not matched...")
            return req.eventLoop.future(HTTPStatus.init(statusCode: 500))
        }
        
        return req.eventLoop.makeSucceededFuture(HTTPStatus.ok)
    }
}
