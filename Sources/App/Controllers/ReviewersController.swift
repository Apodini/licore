//
//  ReviewerssController.swift
//  App
//
//  Created by Oguz Sutanrikulu on 21.03.20.
//

import Vapor
import Leaf

struct ReviewersController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("reviewers", use: reviewers)
        routes.get("reviewers", ":id", "projects", use: reviewerProjects)
        routes.get("reviewers", ":id", "repositories", use: reviewerRepositories)
        
        routes.post("reviewers", ":id", "remove") { req -> EventLoopFuture<Response> in
            return self.removeReviewer(req: req).transform(to: req.redirect(to: "/reviewers"))
        }
        
        routes.post("reviewers", ":id", "projects", ":projectID", "add") { req -> EventLoopFuture<Response> in
            guard let reviewerParameter = req.parameters.get("id") else { return req.eventLoop.future(req.redirect(to: "/reviewers"))}
            
            return self.addProjectReviewer(req: req).transform(to: req.redirect(to: "/reviewers/\(reviewerParameter)/projects"))
        }
        
        routes.post("reviewers", ":id", "projects", ":projectID", "remove") { req -> EventLoopFuture<Response> in
            guard let reviewerParameter = req.parameters.get("id") else { return req.eventLoop.future(req.redirect(to: "/reviewers"))}
            
            return self.removeProjectReviewer(req: req).transform(to: req.redirect(to: "/reviewers/\(reviewerParameter)/projects"))
        }
        
        routes.post("reviewers", ":id", "repositories", ":repoID", "add") { req -> EventLoopFuture<Response> in
            guard let reviewerParameter = req.parameters.get("id") else { return req.eventLoop.future(req.redirect(to: "/reviewers"))}
            
            return self.addRepositoryReviewer(req: req).transform(to: req.redirect(to: "/reviewers/\(reviewerParameter)/repositories"))
        }
        
        routes.post("reviewers", ":id", "repositories", ":repoID", "remove") { req -> EventLoopFuture<Response> in
            guard let reviewerParameter = req.parameters.get("id") else { return req.eventLoop.future(req.redirect(to: "/reviewers"))}
            
            return self.removeRepositoryReviewer(req: req).transform(to: req.redirect(to: "/reviewers/\(reviewerParameter)/repositories"))
        }
        
        routes.post("reviewers") { req -> EventLoopFuture<Response> in
            let context = try req.content.decode(ReviewerPostCreateContext.self)
            
            return self.addReviewer(req: req, context: context).transform(to: req.redirect(to: "/reviewers"))
        }
    }
    
    func reviewers(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        return Reviewer.query(on: req.db).all().flatMap { allReviewers in
            let context = ReviewersContext(reviewers: allReviewers)
            
            return req.view.render("reviewers", context)
        }
    }
    
    func reviewerProjects(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        guard let reviewerParameter = req.parameters.get("id") else { return req.view.render("index") }
        guard let reviewerId = Int(reviewerParameter) else { return req.view.render("index") }
        
        return Reviewer.find(reviewerId, on: req.db).flatMap { reviewer in
            guard let reviewer = reviewer else { return req.view.render("index") }
            
            return ProjectReviewer.query(on: req.db).with(\.$reviewer).with(\.$project).all().flatMap { projectReviewers in
                let projectsReviewers = projectReviewers.filter { $0.reviewer.id == reviewerId }
                let reviewersProjects = projectsReviewers.map { $0.project }
                
                return LicoreProject.query(on: req.db).all().flatMap { allProjects in
                    let projects = allProjects.filter { !reviewersProjects.contains($0) }
                    let context = ReviewersProjectContext(reviewer: reviewer, reviewersProjects: reviewersProjects, projects: projects)
                    
                    return req.view.render("reviewerProjects", context)
                }
            }
        }
    }
    
    func reviewerRepositories(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        guard let reviewerParameter = req.parameters.get("id") else { return req.view.render("index") }
        guard let reviewerId = Int(reviewerParameter) else { return req.view.render("index") }
        
        return Reviewer.find(reviewerId, on: req.db).flatMap { reviewer in
            guard let reviewer = reviewer else { return req.view.render("index") }
            
            return RepositoryReviewer.query(on: req.db).with(\.$reviewer).with(\.$repository).all().flatMap { repositoryReviewers in
                let repositoryReviewer = repositoryReviewers.filter { $0.reviewer.id == reviewerId }
                let reviewersRepositories = repositoryReviewer.map { $0.repository }
                
                return Repository.query(on: req.db).all().flatMap { allRepositories in
                    let repositories = allRepositories.filter { !reviewersRepositories.contains($0) }
                    let context = ReviewersRepositoryContext(reviewer: reviewer,
                                                             reviewersRepositories: reviewersRepositories,
                                                             repositories: repositories)
                    
                    return req.view.render("reviewerRepositories", context)
                }
            }
        }
    }
    
    func addReviewer(req: Request, context: ReviewerPostCreateContext) -> EventLoopFuture<HTTPStatus> {
        let reviewer = Reviewer(slug: context.slug,
                                name: context.name,
                                email: context.email)
        
        return reviewer.save(on: req.db).transform(to: .ok)
    }
    
    func removeReviewer(req: Request) -> EventLoopFuture<HTTPStatus> {
        guard let reviewerParameter = req.parameters.get("id") else { return req.eventLoop.future(.internalServerError) }
        guard let reviewerId = Int(reviewerParameter) else { return req.eventLoop.future(.internalServerError) }
        
        return ProjectReviewer.query(on: req.db).all().flatMap { allProjectReviewers in
            return RepositoryReviewer.query(on: req.db).all().flatMap { allRepositoryReviewers in
                
                allProjectReviewers.forEach { projectReviewer in
                    if projectReviewer.$reviewer.id == reviewerId {
                        projectReviewer.delete(on: req.db)
                    }
                }
                
                allRepositoryReviewers.forEach { repositoryReviewer in
                    if repositoryReviewer.$reviewer.id == reviewerId {
                        repositoryReviewer.delete(on: req.db)
                    }
                }
                
                return Reviewer.find(reviewerId, on: req.db).flatMap { reviewer in
                    guard let reviewer = reviewer else { return req.eventLoop.future(.notFound) }
                    
                    return reviewer.delete(on: req.db).transform(to: .ok)
                }
            }
            
        }
    }
    
    func addProjectReviewer(req: Request) -> EventLoopFuture<HTTPStatus> {
        guard let reviewerParameter = req.parameters.get("id") else { return req.eventLoop.future(.internalServerError) }
        guard let reviewerId = Int(reviewerParameter) else { return req.eventLoop.future(.internalServerError) }
        guard let projectParameter = req.parameters.get("projectID") else { return req.eventLoop.future(.internalServerError) }
        guard let projectId = Int(projectParameter) else { return req.eventLoop.future(.internalServerError) }
        
        return RepositoryReviewer.query(on: req.db).all().flatMap { repositoryReviewers in
            let removingReviewers = repositoryReviewers.filter { $0.$reviewer.id == reviewerId }
            
            removingReviewers.forEach { $0.delete(on: req.db) }
            
            return ProjectReviewer(projectID: projectId, reviewerID: reviewerId).save(on: req.db).transform(to: .ok)
        }
    }
    
    func removeProjectReviewer(req: Request) -> EventLoopFuture<HTTPStatus> {
        guard let reviewerParameter = req.parameters.get("id") else { return req.eventLoop.future(.internalServerError) }
        guard let reviewerId = Int(reviewerParameter) else { return req.eventLoop.future(.internalServerError) }
        guard let projectParameter = req.parameters.get("projectID") else { return req.eventLoop.future(.internalServerError) }
        guard let projectId = Int(projectParameter) else { return req.eventLoop.future(.internalServerError) }
        
        return ProjectReviewer.query(on: req.db).all().flatMap { allProjectReviewers in
            let projectReviewers = allProjectReviewers.filter { $0.$project.id == projectId && $0.$reviewer.id == reviewerId }
            guard let projectReviewer = projectReviewers.first else { return req.eventLoop.future(.internalServerError) }
            
            return projectReviewer.delete(on: req.db).transform(to: .ok)
        }
    }
    
    func addRepositoryReviewer(req: Request) -> EventLoopFuture<HTTPStatus> {
        guard let reviewerParameter = req.parameters.get("id") else { return req.eventLoop.future(.internalServerError) }
        guard let reviewerId = Int(reviewerParameter) else { return req.eventLoop.future(.internalServerError) }
        guard let repositoryParameter = req.parameters.get("repoID") else { return req.eventLoop.future(.internalServerError) }
        guard let repositoryId = Int(repositoryParameter) else { return req.eventLoop.future(.internalServerError) }
        
        return ProjectReviewer.query(on: req.db).all().flatMap { projectReviewers in
            let removingReviewers = projectReviewers.filter { $0.$reviewer.id == reviewerId }
            
            removingReviewers.forEach { $0.delete(on: req.db) }
            
            return RepositoryReviewer(repositoryID: repositoryId, reviewerID: reviewerId).save(on: req.db).transform(to: .ok)
        }
    }
    
    func removeRepositoryReviewer(req: Request) -> EventLoopFuture<HTTPStatus> {
        guard let reviewerParameter = req.parameters.get("id") else { return req.eventLoop.future(.internalServerError) }
        guard let reviewerId = Int(reviewerParameter) else { return req.eventLoop.future(.internalServerError) }
        guard let repositoryParameter = req.parameters.get("repoID") else { return req.eventLoop.future(.internalServerError) }
        guard let repositoryId = Int(repositoryParameter) else { return req.eventLoop.future(.internalServerError) }
        
        return RepositoryReviewer.query(on: req.db).all().flatMap { allRepositoryReviewers in
            let repositoryReviewers = allRepositoryReviewers.filter { $0.$repository.id == repositoryId && $0.$reviewer.id == reviewerId }
            guard let repositoryReviewer = repositoryReviewers.first else { return req.eventLoop.future(.internalServerError) }
            
            return repositoryReviewer.delete(on: req.db).transform(to: .ok)
        }
    }
    
}

struct ReviewerPostCreateContext: Content {
    let slug: String
    let name: String
    let email: String
}

struct ReviewersContext: Content {
    let reviewers: [Reviewer]
}

struct ReviewersProjectContext: Content {
    let reviewer: Reviewer
    let reviewersProjects: [LicoreProject]
    let projects: [LicoreProject]
}

struct ReviewersRepositoryContext: Content {
    let reviewer: Reviewer
    let reviewersRepositories: [Repository]
    let repositories: [Repository]
}
