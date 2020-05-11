//
//  JobsController.swift
//  App
//
//  Created by Oguz Sutanrikulu on 21.03.20.
//

import Vapor
import Leaf

struct JobsController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("jobs", use: allJobs)
        routes.post("jobs", ":id", "retry") { req -> EventLoopFuture<Response> in
            return self.retryJob(req: req).transform(to: req.redirect(to: "/jobs"))
        }
        routes.post("jobs", ":id", "remove") { req -> EventLoopFuture<Response> in
            return self.removeJob(req: req).transform(to: req.redirect(to: "/jobs"))
        }
    }
    
    func allJobs(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login", LoginContext(loginError: true))
        }
        
        return ReviewJobData.query(on: req.db).with(\.$pullRequest).all().flatMap { reviewJobs in
            var reviewJobDataContexts: [ReviewJobDataContext] = []
            
            reviewJobs.forEach { reviewJob in
                let pullRequest = reviewJob.$pullRequest.wrappedValue
                reviewJobDataContexts.append(ReviewJobDataContext(id: reviewJob.id!,
                                                                  status: reviewJob.status,
                                                                  scmId: pullRequest.scmId,
                                                                  latestCommit: String(pullRequest.latestCommit.prefix(8)),
                                                                  refId: pullRequest.refId ?? ""))
            }
            let context = AllJobsContext(reviewJobs: reviewJobDataContexts)
            
            return req.view.render("jobsTable", context)
        }
    }
    
    func retryJob(req: Request) -> EventLoopFuture<HTTPStatus> {
        guard let jobParameter = req.parameters.get("id") else { return req.eventLoop.future(.internalServerError) }
        guard let jobId = Int(jobParameter) else { return req.eventLoop.future(.internalServerError) }
        
        ReviewJobData.query(on: req.db).with(\.$pullRequest) {
            $0.with(\.$repository) {
                $0.with(\.$project) {
                    $0.with(\.$scmSystem)
                }
            }
        }.filter(\.$id, .equal, jobId).first().map { reviewJobData in
            guard let reviewJob = reviewJobData else {
                logger.info("Could not find Review Job!")
                return
            }
            logger.info("Starting Review Process")
            
            switch reviewJob.pullRequest.repository.project.scmSystem.scmType {
            case .bitbucket:
                let review = Review(review: BitBucketReview())
                review.runReview(project: reviewJob.pullRequest.repository.project,
                                 repository: reviewJob.pullRequest.repository,
                                 pullRequest: reviewJob.pullRequest, req: req)
            case .github:
                let review = Review(review: GitHubReview())
                review.runReview(project: reviewJob.pullRequest.repository.project,
                                 repository: reviewJob.pullRequest.repository,
                                 pullRequest: reviewJob.pullRequest, req: req)
            }
        }
        return req.eventLoop.future(.ok)
    }
    
    func removeJob(req: Request) -> EventLoopFuture<HTTPStatus> {
        guard let jobParameter = req.parameters.get("id") else { return req.eventLoop.future(.internalServerError) }
        guard let jobId = Int(jobParameter) else { return req.eventLoop.future(.internalServerError) }
        
        return ReviewJobData.query(on: req.db).filter(\ReviewJobData.$id, .equal, jobId).first().flatMap { reviewJobs in
            guard let reviewJob = reviewJobs else {
                logger.info("Review Job ID not found!")
                return req.eventLoop.future(.notFound)
            }
            
            return reviewJob.delete(on: req.db).transform(to: req.eventLoop.future(.ok))
        }
    }
    
}

struct AllJobsContext: Encodable {
    let title = "All Jobs"
    let reviewJobs: [ReviewJobDataContext]
}

struct ReviewJobDataContext: Content {
    let id: Int
    let status: JobStatus
    let scmId: Int
    let latestCommit: String
    let refId: String
}
