//
//  PullRequestsController.swift
//  App
//
//  Created by Oguz Sutanrikulu on 21.03.20.
//

import Vapor
import Leaf

struct PullRequestsController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("pullRequests", use: allPullRequests)
    }
    
    func allPullRequests(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        return PullRequest.query(on: req.db).all().flatMap { pullRequests in
            let context = AllPullRequestsContext(pullRequests: pullRequests)
            
            return req.view.render("pullRequestsTable", context)
        }
    }
    
}

struct AllPullRequestsContext: Encodable {
    let title = "All Pull Requests"
    let pullRequests: [PullRequest]
}
