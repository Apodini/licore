//
//  ProjectsController.swift
//  App
//
//  Created by Oguz Sutanrikulu on 21.03.20.
//

import Vapor
import Leaf

struct ProjectsController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("projects", use: allProjects)
        routes.get("projects", ":id", use: getProjectOverview)
        routes.post("projects", ":id") { req -> EventLoopFuture<Response> in
            return self.hookAll(req: req).map { _ in
                guard let projectId = req.parameters.get("id") else { return req.redirect(to: "") }
                
                return req.redirect(to: "/projects/" + projectId)
            }
        }
        
        routes.post("projects", ":id", "remove") { req -> EventLoopFuture<Response> in
            return self.removeProject(req: req).transform(to: req.redirect(to: "/projects"))
        }
        
        routes.post("projects", ":id", "removeRepo", ":repoID") { req -> EventLoopFuture<Response> in
            guard let projectId = req.parameters.get("id") else { return req.eventLoop.future(req.redirect(to: "/projects")) }
            return self.removeRepository(req: req).transform(to: req.redirect(to: "/projects/\(projectId)"))
        }
        
        routes.get("projects", ":id", "projectUpdate", use: projectConfigUpdate)
        routes.upload("projects", ":id", "projectUpdate") { req -> EventLoopFuture<Response> in
            let context = try req.content.decode(ProjectPostCreateContext.self)
            guard let projectId = req.parameters.get("id") else { return req.eventLoop.future(req.redirect(to: "/projects")) }
            
            return self.projectPostUpdate(req: req, context: context).transform(to: req.redirect(to: "/projects/\(projectId)"))
        }
        
        routes.post("projects", ":id", "hookSelection", ":repo") { req -> EventLoopFuture<Response> in
            guard let projectId = req.parameters.get("id") else { return req.eventLoop.future(req.redirect(to: "/projects")) }
            
            return self.hookSelection(req: req).map { _ in
                return req.redirect(to: "/projects/" + projectId)
            }
        }
        
        routes.post("projects", ":id", "fetchRepos") { req -> EventLoopFuture<Response> in
            guard let projectId = req.parameters.get("id") else { return req.eventLoop.future(req.redirect(to: "/projects")) }
            
            return self.fetchRepositories(req: req).map { _ in
                return req.redirect(to: "/projects/" + projectId)
            }
        }
        
        routes.post("projects", ":id", "fetchDevelopers") { req -> EventLoopFuture<Response> in
            guard let projectParameter = req.parameters.get("id") else { return req.eventLoop.future(req.redirect(to: "/projects")) }
            guard let projectId = Int(projectParameter) else { return req.eventLoop.future(req.redirect(to: "/projects")) }
            
            return ProjectReviewer.query(on: req.db).with(\.$reviewer).with(\.$project).all().flatMap { projectReviewers in
                let projectsReviewers = projectReviewers.filter { $0.project.id == projectId }
                let reviewers = projectsReviewers.map { $0.reviewer }
                
                return RepositoryReviewer.query(on: req.db).with(\.$repository).with(\.$reviewer).all().map { repositoryReviewers in
                    self.fetchDevelopers(projectReviewers: reviewers, repoReviewers: repositoryReviewers, req: req)
                    
                    return req.redirect(to: "/projects/" + String(projectId))
                }
            }
        }
        
        routes.get("projectConfig", use: projectConfigCreate)
        routes.upload("projectConfig") { req -> EventLoopFuture<Response> in
            let context = try req.content.decode(ProjectPostCreateContext.self)
            
            return self.projectPostCreate(req: req, context: context).transform(to: req.redirect(to: "/projectConfig"))
        }
        
    }
    
    func allProjects(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        return LicoreProject.query(on: req.db).with(\.$scmSystem).all().flatMap { projects in
            let context = IndexContext(title: "All Projects", projects: projects)
            
            return req.view.render("projectsTable", context)
        }
    }
    
    func getProjectOverview(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        guard let projectParameter = req.parameters.get("id") else { return req.view.render("index") }
        guard let projectId = Int(projectParameter) else { return req.view.render("index") }
        
        return Repository.query(on: req.db)
            .with(\.$project) {
                $0.with(\.$scmSystem)
        }
        .all().flatMap { repositories in
            let repos = repositories.filter { $0.$project.id == projectId }
            guard let firstRepo = repos.first else { return req.view.render("index") }
            let project = firstRepo.project
            
            return SourceControlManagementSystem.query(on: req.db).all().flatMap { scmSystems in
                let scmSystem = scmSystems.filter { $0.id ==  project.$scmSystem.id }
                guard let firstScm = scmSystem.first else { return req.view.render("index") }
                let context = ProjectOverviewContext(title: firstRepo.project.name,
                                                     scmSystem: firstScm,
                                                     project: firstRepo.project,
                                                     repositories: repos)
                
                return req.view.render("projectView", context)
            }
        }
    }
    
    func projectConfigCreate(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        return SourceControlManagementSystem.query(on: req.db).all().flatMap { scmSystems in
            let context = ScmSystemsContext(scmSystems: scmSystems)
            return req.view.render("projectConfig", context)
        }
    }
    
    func projectConfigUpdate(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        guard let projectParameter = req.parameters.get("id") else { return req.view.render("index") }
        guard let projectId = Int(projectParameter) else { return req.view.render("index") }
        
        return LicoreProject.find(projectId, on: req.db).flatMap { project in
            guard let project = project else { return req.view.render("index") }
            
            return SourceControlManagementSystem.query(on: req.db).all().flatMap { scmSystems in
                let currentSCM = scmSystems.filter { $0.id == project.$scmSystem.id }.first
                
                let context = ProjectGetUpdateContext(name: project.name,
                                                      key: project.key,
                                                      rules: project.rules,
                                                      slackToken: project.slackToken,
                                                      scmSystemId: currentSCM?.id?.description ?? "1",
                                                      scmSystems: scmSystems)
                return req.view.render("projectConfigUpdate", context)
            }
        }
    }
    
    func projectPostCreate(req: Request, context: ProjectPostCreateContext) -> EventLoopFuture<HTTPStatus> {
        let project = LicoreProject(name: context.name,
                                    key: context.key,
                                    rules: context.rules,
                                    slackToken: context.slackToken ?? "",
                                    scmSystemID: Int(context.scmSystemId) ?? 0)
        
        return project.save(on: req.db).flatMap { _ in
            return project.sourceControlService(req: req).flatMap { sourceControlService in
                
                guard let sourceControlService = sourceControlService else {
                    logger.error("Source Control Service could not be loaded!")
                    return req.eventLoop.future(.internalServerError)
                }
                
                return sourceControlService.getRepositories(req: req).map { repositories in
                    repositories.forEach { repository in
                        if let projectID = project.id {
                            repository.$project.id = projectID
                            repository.create(on: req.db).whenSuccess { _ in
                                logger.info("Repository \(String(describing: repository.id)) - \(repository.name) has been persisted!")
                            }
                        } else {
                            logger.info("Repository \(String(describing: repository.id)) - \(repository.name) has not been persisted!")
                        }
                    }
                    return HTTPStatus.ok
                }
            }
        }
    }
    
    func projectPostUpdate(req: Request, context: ProjectPostCreateContext) -> EventLoopFuture<HTTPStatus> {
        guard let projectParameter = req.parameters.get("id") else { return req.eventLoop.future(.internalServerError) }
        guard let projectId = Int(projectParameter) else { return req.eventLoop.future(.internalServerError) }
        
        return LicoreProject.find(projectId, on: req.db).flatMap { project in
            guard let project = project else { return req.eventLoop.future(.internalServerError) }
            guard let scmSystemID = Int(context.scmSystemId) else { return req.eventLoop.future(.internalServerError) }
            
            project.name = context.name
            project.key = context.key
            project.rules = context.rules
            project.$scmSystem.id = scmSystemID
            
            return project.update(on: req.db).transform(to: .ok)
        }
    }
    
    func removeProject(req: Request) -> EventLoopFuture<HTTPStatus> {
        guard let projectParameter = req.parameters.get("id") else { return req.eventLoop.future(.internalServerError) }
        guard let projectId = Int(projectParameter) else { return req.eventLoop.future(.internalServerError) }
        
        return LicoreProject.find(projectId, on: req.db).flatMap { project in
            guard let project = project else { return req.eventLoop.future(.internalServerError) }
            
            return project.delete(on: req.db).transform(to: .ok)
        }
    }
    
    func removeRepository(req: Request) -> EventLoopFuture<HTTPStatus> {
        guard let repoParameter = req.parameters.get("repoID") else { return req.eventLoop.future(.internalServerError) }
        guard let repoId = Int(repoParameter) else { return req.eventLoop.future(.internalServerError) }
        
        return Repository.find(repoId, on: req.db).flatMap { repository in
            guard let repository = repository else { return req.eventLoop.future(.internalServerError) }
            
            return repository.delete(on: req.db).transform(to: .ok)
        }
    }
    
    func fetchDevelopers(projectReviewers: [Reviewer], repoReviewers: [RepositoryReviewer], req: Request) -> EventLoopFuture<HTTPStatus> {
        guard let projectParameter = req.parameters.get("id") else { return req.eventLoop.future(.internalServerError) }
        guard let projectId = Int(projectParameter) else { return req.eventLoop.future(.internalServerError) }
        
        return Repository.query(on: req.db).with(\.$project).all().flatMap { allRepositories in
            let repositories = allRepositories.filter { $0.$project.id == projectId }
            guard let project = repositories.first?.project else { return req.eventLoop.future(.ok) }
            
            let projectReviewerSlugs = projectReviewers.map { $0.slug }
            
            repositories.forEach { repository in
                guard let repositoryID = repository.id else { return }
                
                project.sourceControlService(req: req).whenSuccess { sourceControlService in
                    sourceControlService?.getDevelopers(repositoryName: repository.name, req: req).whenSuccess { allDevelopers in
                        allDevelopers.forEach { developer in
                            let repositoryReviewersSlugs = repoReviewers.filter { $0.repository.id == repositoryID }.map { $0.reviewer.slug }
                            
                            if !projectReviewerSlugs.contains(developer.slug) && !repositoryReviewersSlugs.contains(developer.slug) {
                                
                                Developer.query(on: req.db).all().map { allDevelopers in
                                    if let persistedDeveloperID = allDevelopers.filter { $0.slug == developer.slug }.first?.id {
                                        RepositoryDeveloper(repositoryID: repositoryID, developerID: persistedDeveloperID).save(on: req.db).map {
                                            logger.info("Developer '\(developer.slug)' mapped to Repository '\(repository.name)'!")
                                        }
                                    } else {
                                        developer.save(on: req.db).map {
                                            logger.info("Developer '\(developer.slug)' persisted!")
                                            
                                            Developer.query(on: req.db).all().map { allPersistedDevelopers in
                                                let persistedDevelopers = allPersistedDevelopers.filter { $0.slug ==  developer.slug}
                                                guard let persistedDeveloperID = persistedDevelopers.first?.id else {
                                                    logger.error("Could not unwrap persisted developers ID!")
                                                    return
                                                }
                                                
                                                RepositoryDeveloper(repositoryID: repositoryID,
                                                                    developerID: persistedDeveloperID).save(on: req.db).map {
                                                    logger.info("Developer '\(developer.slug)' mapped to Repository '\(repository.name)'!")
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
            return req.eventLoop.future(.ok)
        }
    }
    
    func fetchRepositories(req: Request) -> EventLoopFuture<HTTPStatus> {
        guard let projectParameter = req.parameters.get("id") else { return req.eventLoop.future(.internalServerError) }
        guard let projectId = Int(projectParameter) else { return req.eventLoop.future(.internalServerError) }
        
        return LicoreProject.find(projectId, on: req.db).map { project in
            guard let project = project else { return .internalServerError }
            
            project.sourceControlService(req: req).map { sourceControlService in
                
                guard let sourceControlService = sourceControlService else {
                    logger.error("Source Control Service could not be loaded!")
                    return
                }
                
                Repository.query(on: req.db).with(\.$project).all().map { allRepositories in
                    let existingRepositoryScmIDs = allRepositories.filter { $0.project.id == project.id }.map { $0.scmId }
                    sourceControlService.getRepositories(req: req).map { repositories in
                        repositories.map { repository in
                            if !existingRepositoryScmIDs.contains(repository.scmId) {
                                repository.$project.id = projectId
                                repository.save(on: req.db)
                            }
                        }
                    }
                }
            }
            return HTTPStatus.ok
        }
    }
    
    func hookAll(req: Request) -> EventLoopFuture<HTTPStatus> {
        guard let projectParameter = req.parameters.get("id") else { return req.eventLoop.future(.internalServerError) }
        guard let projectId = Int(projectParameter) else { return req.eventLoop.future(.internalServerError) }
        
        return Repository.query(on: req.db).with(\.$project).all().flatMap { repositories in
            let repos = repositories.filter { $0.$project.id == projectId }
            guard let project = repos.first?.project else { return req.eventLoop.future(.ok) }
            repos.map { repo in
                project.sourceControlService(req: req).map { sourceControlService in
                    
                    guard let sourceControlService = sourceControlService else {
                        logger.error("Source Control Service could not be loaded!")
                        return
                    }
                    
                    sourceControlService.hookRepository(project: project, repositoryName: repo.name, hookURL: Application.hookURL, req: req)
                }
            }
            return req.eventLoop.future(.ok)
        }
    }
    
    func hookSelection(req: Request) -> EventLoopFuture<HTTPStatus> {
        guard let projectParameter = req.parameters.get("id") else { return req.eventLoop.future(.internalServerError) }
        guard let projectId = Int(projectParameter) else { return req.eventLoop.future(.internalServerError) }
        guard let repositoryName = req.parameters.get("repo") else { return req.eventLoop.future(.internalServerError) }
        
        return LicoreProject.find(projectId, on: req.db).flatMap { project in
            guard let project = project else { return req.eventLoop.future(.ok) }
            
            return project.sourceControlService(req: req).flatMap { sourceControlService in
                
                guard let sourceControlService = sourceControlService else {
                    logger.error("Source Control Service could not be loaded!")
                    return req.eventLoop.future(HTTPStatus.internalServerError)
                }
                
                return sourceControlService.hookRepository(project: project,
                                                           repositoryName: repositoryName,
                                                           hookURL: Application.hookURL,
                                                           req: req).transform(to: HTTPStatus.ok)
            }
        }
    }
    
}

struct AllProjectsContext: Encodable {
    let title = "All Projects"
    let projects: [ProjectContext]
}
struct ProjectOverviewContext: Encodable {
    let title: String
    let scmSystem: SourceControlManagementSystem
    let project: LicoreProject
    let repositories: [Repository]
}

struct ProjectContext: Codable {
    let id: Int
    let name: String
    let scmType: String
    let scmURL: String
}

struct ProjectPostCreateContext: Content {
    let name: String
    let key: String
    let rules: String
    let slackToken: String?
    let scmSystemId: String
}

struct ProjectGetUpdateContext: Content {
    let name: String
    let key: String
    let rules: String
    let slackToken: String?
    let scmSystemId: String
    let scmSystems: [SourceControlManagementSystem]
}
