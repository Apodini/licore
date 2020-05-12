//
//  SourceControlServable.swift
//  App
//
//  Created by Oguz Sutanrikulu on 15.12.19.
//

import Vapor

//This protocol specifies a common interface for communicating to a remote source control management system.
public protocol SourceControlServable {
    func getDevelopers(repositoryName: String, req: Request) -> EventLoopFuture<[Developer]>
    func getRepositories(req: Request) -> EventLoopFuture<[Repository]>
    func getComments(repositoryName: String, pullRequestId: Int, req: Request) -> EventLoopFuture<[Comment]>
    func postComment(repositoryName: String, pullRequest: PullRequest, comment: Comment, diff: Diff, req: Request) -> EventLoopFuture<HTTPStatus>
    func postGeneralComment(repositoryName: String, pullRequest: PullRequest, comments: [Comment], req: Request) -> EventLoopFuture<HTTPStatus>
    func deleteAllComments(repositoryName: String, pullRequestId: Int, req: Request)
    func getTasks(repositoryName: String, pullRequest: PullRequest, req: Request) -> EventLoopFuture<[Task?]>
    func postTasks(repositoryName: String, pullRequest: PullRequest, tasks: [Task], req: Request) -> EventLoopFuture<HTTPStatus>
    func resolveTask(id: Int, req: Request) -> EventLoopFuture<HTTPStatus>
    func approvePullRequest(repositoryName: String, pullRequest: PullRequest, req: Request) -> EventLoopFuture<HTTPStatus>
    func markNeedsRework(repositoryName: String, pullRequest: PullRequest, req: Request) -> EventLoopFuture<HTTPStatus>
    func hookRepository(project: LicoreProject, repositoryName: String, hookURL: String, req: Request) -> EventLoopFuture<HTTPStatus>
    func getPullRequest(repositoryName: String, pullRequestId: Int, req: Request) -> EventLoopFuture<PullRequest?>
    func getPullRequests(repositoryName: String, req: Request) -> EventLoopFuture<[PullRequest]>
    func getDiff(repositoryName: String, pullRequestId: Int, req: Request) -> EventLoopFuture<Diff>
    func downloadSources(pullRequest: PullRequest, req: Request, completion: @escaping () -> Void)
}
