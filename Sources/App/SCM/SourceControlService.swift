//
//  SourceControlService.swift
//  App
//
//  Created by Oguz Sutanrikulu on 10.12.19.
//

import Vapor

///This service interacts with the respective `SourceControlMangementSystem` specified in the `LicoreProject`.
public struct SourceControlService {

    let service: SourceControlServable
    
    public init(service: SourceControlServable) {
        self.service = service
    }
    
    public func downloadSources(pullRequest: PullRequest,
                                req: Request,
                                completion: @escaping () -> Void) {
        service.downloadSources(pullRequest: pullRequest, req: req, completion: completion)
    }
    
    public func hookRepository(project: LicoreProject,
                               repositoryName: String,
                               hookURL: String,
                               req: Request) -> EventLoopFuture<HTTPStatus> {
        service.hookRepository(project: project, repositoryName: repositoryName, hookURL: hookURL, req: req)
    }
    
    public func getDevelopers(repositoryName: String,
                              req: Request) -> EventLoopFuture<[Developer]> {
        service.getDevelopers(repositoryName: repositoryName, req: req)
    }
    
    public func getRepositories(req: Request) -> EventLoopFuture<[Repository]> {
        service.getRepositories(req: req)
    }
    
    public func getComments(repositoryName: String, pullRequestId: Int, req: Request) -> EventLoopFuture<[Comment]> {
        service.getComments(repositoryName: repositoryName, pullRequestId: pullRequestId, req: req)
    }
    
    public func getDiff(repositoryName: String,
                        pullRequestId: Int,
                        req: Request) -> EventLoopFuture<Diff> {
        service.getDiff(repositoryName: repositoryName, pullRequestId: pullRequestId, req: req)
    }

    public func postComment(repositoryName: String,
                            pullRequest: PullRequest,
                            diff: Diff,
                            comment: Comment,
                            req: Request) -> EventLoopFuture<HTTPStatus> {
        service.postComment(repositoryName: repositoryName, pullRequest: pullRequest, comment: comment, diff: diff, req: req)
    }
    
    public func postGeneralComment(repositoryName: String,
                                   pullRequest: PullRequest,
                                   comments: [Comment],
                                   req: Request) -> EventLoopFuture<HTTPStatus> {
        service.postGeneralComment(repositoryName: repositoryName, pullRequest: pullRequest, comments: comments, req: req)
    }
    
    public func deleteAllComments(repositoryName: String,
                                  pullRequestId: Int,
                                  req: Request) {
        service.deleteAllComments(repositoryName: repositoryName, pullRequestId: pullRequestId, req: req)
    }
    
    public func getTasks(repositoryName: String,
                         pullRequest: PullRequest,
                         req: Request) -> EventLoopFuture<[Task?]> {
        service.getTasks(repositoryName: repositoryName, pullRequest: pullRequest, req: req)
    }
    
    public func postTasks(repositoryName: String,
                          pullRequest: PullRequest,
                          tasks: [Task],
                          req: Request) -> EventLoopFuture<HTTPStatus> {
        service.postTasks(repositoryName: repositoryName,
                          pullRequest: pullRequest,
                          tasks: tasks,
                          req: req)
    }
    
    public func resolveTask(id: Int,
                            req: Request) -> EventLoopFuture<HTTPStatus> {
        service.resolveTask(id: id, req: req)
    }

    public func getPullRequest(repositoryName: String,
                               pullRequestId: Int,
                               req: Request) -> EventLoopFuture<PullRequest?> {
        service.getPullRequest(repositoryName: repositoryName, pullRequestId: pullRequestId, req: req)
    }

    public func getPullRequests(repositoryName: String,
                                req: Request) -> EventLoopFuture<[PullRequest]> {
        service.getPullRequests(repositoryName: repositoryName, req: req)
    }

    public func approvePullRequest(repositoryName: String,
                                   pullRequest: PullRequest,
                                   req: Request) -> EventLoopFuture<HTTPStatus> {
        service.approvePullRequest(repositoryName: repositoryName, pullRequest: pullRequest, req: req)
    }
    
    public func markNeedsRework(repositoryName: String,
                                pullRequest: PullRequest,
                                req: Request) -> EventLoopFuture<HTTPStatus> {
        service.markNeedsRework(repositoryName: repositoryName, pullRequest: pullRequest, req: req)
    }
    
}
