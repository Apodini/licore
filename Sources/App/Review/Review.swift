//
//  Review.swift
//  App
//
//  Created by Oguz Sutanrikulu on 24.12.19.
//

import Vapor
import SwiftLintFramework

class Review {
    
    let review: Reviewable
    
    public init(review: Reviewable) {
        self.review = review
    }
    
    public func runReview(project: LicoreProject, repository: Repository, pullRequest: PullRequest, req: Request) {
        review.runReview(project: project, repository: repository, pullRequest: pullRequest, req: req)
    }
    
}