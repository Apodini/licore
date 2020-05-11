//
//  WebhooksController.swift
//  App
//
//  Created by Oguz Sutanrikulu on 05.01.20.
//

import Vapor
import Queues

struct WebhooksController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        routes.post("inc") { req -> EventLoopFuture<HTTPStatus> in
            logger.info("\(req.content)")
            logger.info("\(req.body)")
            
            if req.headers.first(name: "X-Event-Key") == "diagnostics:ping" {
                return req.eventLoop.future(.ok)
            }
            
            guard let userAgent = req.headers.first(name: .userAgent) else {
                logger.error("User Agent Header not found!")
                return req.eventLoop.future(.notFound)
            }
            
            var scmType: SourceControlType?
            
            userAgent.contains("Bitbucket") ? scmType = .bitbucket : nil
            userAgent.contains("GitHub") ? scmType = .github : nil
            
            guard let scmSystem = scmType else {
                logger.error("Unknown Source Control Management System!")
                return req.eventLoop.future(.badRequest)
            }
            
            switch scmSystem {
            case .bitbucket:
                logger.info("Incoming Webhook from Bitbucket!")
                let webhookContent = try req.content.decode(BitBucketWebhookResponse.self)
                
                self.addToQueue(req: req, webhookContent: webhookContent)
            case .github:
                logger.info("Incoming Webhook from GitHub!")
                var webhookContent = try req.content.decode(GitHubWebhookResponse.self)
                
                guard let gitHubEvent = req.headers.first(name: "X-GitHub-Event") else {
                    logger.error("GitHub Event Header not found!")
                    return req.eventLoop.future(.notFound)
                }
                
                webhookContent.eventKey = gitHubEvent
                
                self.addToQueue(req: req, webhookContent: webhookContent)
            }
            
            return req.eventLoop.future(.ok)
        }
        
        routes.get("setHookUrl", use: setHookURL)
        routes.post("setHookUrl") { req -> EventLoopFuture<Response> in
            let context = try req.content.decode(WebhookPostQuickCreateContext.self)
            
            return self.setConfig(req: req, context: context).transform(to: req.redirect(to: "/setHookUrl"))
        }
        
        routes.get("createWebhook", use: createWebhook)
        routes.post("createWebhook") { req -> EventLoopFuture<Response> in
            let context = try req.content.decode(WebhookPostCreateContext.self)
            
            return self.createWebhook(req: req, context: context).transform(to: req.redirect(to: "/createWebhook"))
        }
    }
    
    func setHookURL(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        return req.view.render("setHookUrl")
    }
    
    func createWebhook(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        return req.view.render("createWebhook")
    }
    
    func createWebhook(req: Request, context: WebhookPostCreateContext) -> EventLoopFuture<HTTPStatus> {
        return LicoreProject.query(on: req.db).all().flatMap { projects in
            let currentProject = projects.filter { $0.key == context.project }.first
            guard let project = currentProject else { return req.eventLoop.future(.internalServerError) }
            
            return project.sourceControlService(req: req).flatMap { sourceControlService in
                guard let sourceControlService = sourceControlService else {
                    logger.error("Source Control Service could not be loaded!")
                    return req.eventLoop.future(.internalServerError)
                }
                return sourceControlService.hookRepository(project: project,
                                                           repositoryName: context.repo,
                                                           hookURL: context.url,
                                                           req: req).transform(to: .ok)
            }
        }
    }
    
    func setConfig(req: Request, context: WebhookPostQuickCreateContext) -> EventLoopFuture<HTTPStatus> {
        let config = LicoreConfig(hookURL: context.url)
        
        return config.save(on: req.db).map {
            Application.hookURL = config.hookURL
        }.transform(to: .ok)
    }
    
    func addToQueue(req: Request, webhookContent: BitBucketWebhookResponse) -> EventLoopFuture<HTTPStatus> {
        logger.info("\(req.content)")
        
        switch webhookContent.eventKey {
        case "pr:opened":
            logger.info("Pull Request Opened...")
            
            guard let pullRequest = webhookContent.pullRequest?.createLicoreModel() else {
                logger.warning("Webhook Content: Pull Request not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            guard let projectKey = webhookContent.pullRequest?.fromRef.repository.project.key else {
                logger.warning("Webhook Content: Project Key not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            guard let repository = webhookContent.pullRequest?.fromRef.repository else {
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
                        PullRequest.query(on: req.db).with(\.$repository).all().map { pullRequests in
                            let persistedPullRequest = pullRequests.filter { $0.scmId == pullRequest.scmId && repoID == $0.repository.id }
                            
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
            
        case "repo:refs_changed":
            logger.info("Refs Changed...")
            
            guard let changes = webhookContent.changes else {
                logger.warning("Webhook Content: No Changes found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            guard let repository = webhookContent.repository else {
                logger.warning("Webhook Content: Repository not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            guard let change = changes.first else {
                logger.warning("Webhook Content: No Change found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            
            if change.type == "ADD" {
                logger.info("...with Change Type 'ADD'")
                
                Repository.query(on: req.db).with(\.$project).all().map { repositories in
                    let repos = repositories.filter { $0.project.key == repository.project.key && $0.scmId == repository.id }
                    guard let repoID = repos.first?.id else {
                        logger.warning("Webhook Content: Repository ID \(repository.id) unknown!")
                        return
                    }
                    
                    guard let date = ISO8601DateFormatter().date(from: webhookContent.date) else {
                        logger.warning("Creation Date could not be formatted to ISO860!")
                        return
                    }
                    let interval = date.timeIntervalSince1970
                    
                    Branch(creationDate: interval, refId: change.refId, repositoryID: repoID).save(on: req.db)
                }
            } else {
                LicoreProject.query(on: req.db).filter(\LicoreProject.$key, .equal, repository.project.key).first().map { project in
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
                        
                        sourceControlService.getPullRequests(repositoryName: repository.slug, req: req).whenSuccess { pullRequests in
                            
                            pullRequests.first { preq in
                                guard let refId = preq.refId else {
                                    logger.warning("Ref ID not found!")
                                    return false
                                }
                                
                                return refId == change.refId
                            }.map { matchedPR in
                                pullRequest = matchedPR
                            }
                            
                            guard let pullRequest = pullRequest else {
                                logger.warning("Pull Request not found!")
                                return
                            }
                            
                            PullRequest.query(on: req.db).with(\.$repository).all().map { allPullRequests in
                                let currentRepoPullRequests = allPullRequests.filter { $0.repository.name == repository.slug }
                                guard let currentPullRequest = currentRepoPullRequests.filter { $0.scmId == pullRequest.scmId }.first else {
                                    logger.warning("Pull Request not matched with database!")
                                    return
                                }
                                
                                currentPullRequest.latestCommit = pullRequest.latestCommit
                                currentPullRequest.update(on: req.db).whenSuccess {
                                    guard let currentPullRequestID = currentPullRequest.id else {
                                        logger.warning("Pull Request ID not in database!")
                                        return
                                    }
                                    
                                    let jobData = ReviewJobData(pullRequestID: currentPullRequestID)
                                    jobData.save(on: req.db).whenSuccess {
                                        req.queue.dispatch(ReviewJob.self, jobData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            return req.eventLoop.makeSucceededFuture(HTTPStatus.ok)
            
        case "pr:reviewer:approved":
            logger.info("Pull Request Approved...")
            
            guard let approvedPullRequest = webhookContent.pullRequest else {
                logger.warning("Approved Pull Request not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            guard let previousStatus = webhookContent.previousStatus else {
                logger.warning("Previous Pull Request Status not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            
            PullRequest.query(on: req.db).all().map { pullRequests in
                let pullRequestsFiltered = pullRequests.filter { $0.scmId == approvedPullRequest.id }
                guard let pullRequestID = pullRequestsFiltered.first?.id else {
                    logger.warning("Pull Request ID not found!")
                    return
                }
                
                guard let date = ISO8601DateFormatter().date(from: webhookContent.date) else {
                    logger.warning("Creation Date could not be formatted to ISO860!")
                    return
                }
                let interval = date.timeIntervalSince1970
                
                StatusChange(previousStatus: previousStatus, newStatus: .approved, date: interval, pullRequestID: pullRequestID).save(on: req.db)
            }
            return req.eventLoop.makeSucceededFuture(HTTPStatus.ok)
            
        case "pr:reviewer:needs_work":
            logger.info("Pull Request Needs Rework...")
            
            guard let approvedPullRequest = webhookContent.pullRequest else {
                logger.warning("Approved Pull Request not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            guard let previousStatus = webhookContent.previousStatus else {
                logger.warning("Previous Pull Request Status not found!")
                return req.eventLoop.future(HTTPStatus.init(statusCode: 404))
            }
            
            PullRequest.query(on: req.db).all().map { pullRequests in
                let pullRequestsFiltered = pullRequests.filter { $0.scmId == approvedPullRequest.id }
                guard let pullRequestID = pullRequestsFiltered.first?.id else {
                    logger.warning("Pull Request ID not found!")
                    return
                }
                
                guard let date = ISO8601DateFormatter().date(from: webhookContent.date) else {
                    logger.warning("Creation Date could not be formatted to ISO860!")
                    return
                }
                let interval = date.timeIntervalSince1970
                
                StatusChange(previousStatus: previousStatus, newStatus: .rework, date: interval, pullRequestID: pullRequestID).save(on: req.db)
            }
            return req.eventLoop.makeSucceededFuture(HTTPStatus.ok)
            
        default:
            logger.warning("Bitbucket Event Key not matched...")
            return req.eventLoop.future(HTTPStatus.init(statusCode: 500))
        }
    }
    
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

struct WebhookPostQuickCreateContext: Content {
    let url: String
}

struct WebhookPostCreateContext: Content {
    let title = "Create a Webhook"
    let project: String
    let repo: String
    let url: String
}
