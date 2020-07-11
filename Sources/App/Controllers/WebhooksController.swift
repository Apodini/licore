//
//  WebhooksController.swift
//  App
//
//  Created by Oguz Sutanrikulu on 05.01.20.
//

import Vapor
import Queues


struct WebhookPostQuickCreateContext: Content {
    let url: String
}


struct WebhookPostCreateContext: Content {
    let title = "Create a Webhook"
    let project: String
    let repo: String
    let url: String
}


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
                
                return self.addToQueue(req: req, webhookContent: webhookContent)
            case .github:
                logger.info("Incoming Webhook from GitHub!")
                var webhookContent = try req.content.decode(GitHubWebhookResponse.self)
                
                guard let gitHubEvent = req.headers.first(name: "X-GitHub-Event") else {
                    logger.error("GitHub Event Header not found!")
                    return req.eventLoop.future(.notFound)
                }
                
                webhookContent.eventKey = gitHubEvent
                
                return self.addToQueue(req: req, webhookContent: webhookContent)
            }
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
        LicoreProject
            .query(on: req.db)
            .all()
            .flatMap { projects in
                guard let project = projects.first(where: { $0.key == context.project }) else {
                    return req.eventLoop.future(.internalServerError)
                }
                
                return project.sourceControlService(req: req)
                    .flatMap { sourceControlService in
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
        LicoreConfig(hookURL: context.url)
            .save(on: req.db)
            .map {
                Application.hookURL = context.url
            }
            .transform(to: .ok)
    }
}
