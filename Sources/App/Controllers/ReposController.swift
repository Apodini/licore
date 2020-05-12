//
//  ReposController.swift
//  App
//
//  Created by Oguz Sutanrikulu on 21.03.20.
//

import Vapor
import Leaf

struct ReposController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("repos", use: allRepositories)
        routes.get("repos", ":repoID", use: getRepositoryOverview)
        routes.get("repos", ":repoID", "iterations", use: getIterationsOverview)
        routes.get("repos", ":repoID", "violations", use: getViolationsOverview)
    }
    
    func allRepositories(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        return Repository.query(on: req.db).all().flatMap { repositories in
            let context = AllRepositoriesContext(repositories: repositories)
            
            return req.view.render("repositoriesTable", context)
        }
    }
    
    func getRepositoryOverview(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        guard let repositoryParameter = req.parameters.get("repoID") else {
            return req.view.render("index")
        }
        guard let repositoryId = Int(repositoryParameter) else {
            return req.view.render("index")
        }
        
        var openingTimes: [Double] = []
        var iterations: [Double] = []
        var approvalDistances: [Double] = []
        var averageResolvingTime: Double = 0.0
        
        return RepositoryDeveloper.query(on: req.db).with(\.$repository).with(\.$developer).all().flatMap { repositoryDevelopers in
            let repositoryDeveloper = repositoryDevelopers.filter { $0.$repository.id == repositoryId }
            guard let developer = repositoryDeveloper.map({ $0.developer }).first else {
                return req.view.render("index")
            }
            guard let repository = repositoryDeveloper.map({ $0.repository }).first else {
                return req.view.render("index")
            }
            
            return Branch.query(on: req.db).with(\.$repository).all().flatMap { branches in
                let branches = branches.filter { $0.$repository.id == repository.id }
                
                return PullRequest.query(on: req.db).all().flatMap { pullRequests in
                    branches.forEach { branch in
                        let pullRequests = pullRequests.filter { branch.refId == $0.refId }
                        let iteration = pullRequests.filter { branch.refId == $0.refId }.count
                        
                        iterations.append(Double(iteration))
                        
                        if let firstPullRequest = pullRequests.first {
                            let distance = firstPullRequest.creationDate / 1000 - branch.creationDate
                            print(distance)
                            
                            openingTimes.append(distance)
                        }
                    }
                    
                    let averageTimeUntilOpening = openingTimes.reduce(0, +) / Double(openingTimes.count)
                    let averageIterations = iterations.reduce(0, +) / Double(iterations.count)
                    
                    return StatusChange.query(on: req.db).with(\.$pullRequest).all().flatMap { allStatusChanges in
                        pullRequests.map { pullRequest in
                            let statusChanges = allStatusChanges.filter { $0.pullRequest.id == pullRequest.id }
                            let rework = statusChanges.filter { $0.newStatus == .rework }
                            let approvals = statusChanges.filter { $0.newStatus == .approved }
                            
                            let distances = zip(rework, approvals)
                            
                            distances.map {
                                approvalDistances.append($1.date - $0.date)
                            }
                            
                            if !approvalDistances.isEmpty {
                                averageResolvingTime = approvalDistances.reduce(0, +) / Double(approvalDistances.count)
                            }
                        }
                        
                        return ReviewStatistics.query(on: req.db).with(\.$developer).all().flatMap { statistics in
                            let statistics = statistics.filter { $0.developer.id == developer.id }
                            
                            if statistics.isEmpty {
                                let context = RepositoryOverviewContext(repository: repository,
                                                                        developer: developer,
                                                                        averageResolvingTime: "n/a",
                                                                        averageIterations: "n/a",
                                                                        averageTimeUntilOpening: "n/a",
                                                                        averageViolations: "n/a")
                                
                                return req.view.render("repositoryOverview", context)
                            } else {
                                let averageViolations = statistics.compactMap { $0.sumViolations }.reduce(0, +) / statistics.count
                                let resolvingTime = averageResolvingTime.isNaN ? 0 : averageResolvingTime
                                let iterations = averageIterations.isNaN ? 0 : averageIterations
                                let timeUntilOpening = averageTimeUntilOpening.isNaN ? 0 : averageTimeUntilOpening
                                
                                let resolvingTimeHours = Int(resolvingTime).hours.description + "h" + " "
                                let resolvingTimeMinutes = Int(resolvingTime).minutes.description + "m" + " "
                                let resolvingTimeSeconds = Int(resolvingTime).seconds.description + "s"
                                let averageResolvingTime = resolvingTimeHours + resolvingTimeMinutes + resolvingTimeSeconds
                                
                                let timeUntilOpeningHours = Int(timeUntilOpening).hours.description + "h" + " "
                                let timeUntilOpeningMinutes = Int(timeUntilOpening).minutes.description + "m" + " "
                                let timeUntilOpeningSeconds = Int(timeUntilOpening).seconds.description + "s"
                                let averageTimeUntilOpening = timeUntilOpeningHours + timeUntilOpeningMinutes + timeUntilOpeningSeconds
                                
                                let context = RepositoryOverviewContext(repository: repository,
                                                                        developer: developer,
                                                                        averageResolvingTime: averageResolvingTime,
                                                                        averageIterations: Int(iterations).description,
                                                                        averageTimeUntilOpening: averageTimeUntilOpening,
                                                                        averageViolations: averageViolations.description)
                                
                                return req.view.render("repositoryOverview", context)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func getIterationsOverview(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        guard let repositoryParameter = req.parameters.get("repoID") else {
            return req.view.render("index")
        }
        guard let repositoryId = Int(repositoryParameter) else {
            return req.view.render("index")
        }
        
        var contexts: [BranchContext] = []
        
        return RepositoryDeveloper.query(on: req.db).with(\.$repository).all().flatMap { repositoryDevelopers in
            let repositoryDeveloper = repositoryDevelopers.filter { $0.$repository.id == repositoryId }
            guard let repository = repositoryDeveloper.map({ $0.repository }).first else {
                return req.view.render("index")
            }
            
            return Branch.query(on: req.db).with(\.$repository).all().flatMap { branches in
                let branches = branches.filter { $0.$repository.id == repository.id }
                
                return PullRequest.query(on: req.db).all().flatMap { pullRequests in
                    branches.forEach { branch in
                        
                        guard let branchID = branch.id else {
                            return
                        }
                        let iteration = pullRequests.filter { branch.refId == $0.refId }.count
                        
                        contexts.append(BranchContext(id: branchID,
                                                      creationDate: Date(timeIntervalSince1970: TimeInterval(branch.creationDate)).description,
                                                      refId: branch.refId,
                                                      iterations: iteration.description))
                    }
                    return req.view.render("iterationsTable", BranchOverviewContext(branches: contexts))
                }
            }
        }
    }
    
    func getViolationsOverview(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        guard let repositoryParameter = req.parameters.get("repoID") else {
            return req.view.render("index")
        }
        guard let repositoryId = Int(repositoryParameter) else {
            return req.view.render("index")
        }
        
        var contexts: [ViolationContext] = []
        
        return RepositoryDeveloper.query(on: req.db).with(\.$repository).with(\.$developer).all().flatMap { repositoryDevelopers in
            let developers = repositoryDevelopers.filter { $0.$repository.id == repositoryId }.map { $0.developer }
            guard let developer = developers.first else {
                return req.view.render("index")
            }
            
            return ReviewStatistics.query(on: req.db).with(\.$developer).all().flatMap { statistics in
                let statistics = statistics.filter { $0.developer.id == developer.id }
                
                let violations = statistics.map { $0.violations }
                let keys = violations.map { $0.keys.compactMap { $0 } }.first
                guard let keysArray = keys else {
                    return req.view.render("index")
                }
                
                keysArray.map { key in
                    let violation = violations.filter { $0.contains { $0.key == key.description } }
                    
                    let avg = Double(violation.compactMap { $0[key.description] }.reduce(0, +) / violation.count)
                    let total = violation.compactMap { $0[key.description] }.reduce(0, +)
                    
                    contexts.append(ViolationContext(name: key.description, occurence: total.description, average: avg.description))
                }
                return req.view.render("violationsTable", ViolationsOverviewContext(violations: contexts))
            }
        }
    }
}

struct AllRepositoriesContext: Encodable {
    let title = "All Repositories"
    let repositories: [Repository]
}

struct RepositoryOverviewContext: Content {
    let repository: Repository
    let developer: Developer
    let averageResolvingTime: String
    let averageIterations: String
    let averageTimeUntilOpening: String
    let averageViolations: String
}

struct ViolationsOverviewContext: Content {
    let violations: [ViolationContext]
}

struct ViolationContext: Content {
    let name: String
    let occurence: String
    let average: String
}

struct BranchOverviewContext: Content {
    let branches: [BranchContext]
}

struct BranchContext: Content {
    let id: Int
    let creationDate: String
    let refId: String
    let iterations: String
}

extension Int {
    var seconds: Int {
        self % 60
    }
    
    var minutes: Int {
        (self % 3600) / 60
    }
    
    var hours: Int {
        (self % 86400) / 3600
    }
}
