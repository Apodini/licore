//
//  ReviewJob.swift
//  App
//
//  Created by Oguz Sutanrikulu on 22.12.19.
//

import Vapor
import Queues
import Fluent

struct ReviewJob: Job {
    
    let req: Request
    
    func dequeue(_ context: QueueContext, _ payload: ReviewJobData) -> EventLoopFuture<Void> {
        logger.info("Dequeueing Review Job")
        
        guard let reviewJobID = payload.id else {
            logger.info("Review Job ID not found!")
            return req.eventLoop.future()
        }
        
        ReviewJobData.query(on: req.db).filter(\.$id, .equal, reviewJobID).with(\.$pullRequest) {
            $0.with(\.$repository) {
                $0.with(\.$project) {
                    $0.with(\.$scmSystem)
                }
            }
        }.first().map { reviewJobData in
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
                                 pullRequest: reviewJob.pullRequest,
                                 req: self.req)
            case .github:
                let review = Review(review: GitHubReview())
                review.runReview(project: reviewJob.pullRequest.repository.project,
                                 repository: reviewJob.pullRequest.repository,
                                 pullRequest: reviewJob.pullRequest,
                                 req: self.req)
            }
        }
        return context.eventLoop.future()
    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: ReviewJobData) -> EventLoopFuture<Void> {
        return context.eventLoop.makeSucceededFuture(())
    }
}
