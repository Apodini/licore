//
//  BitBucketService.swift
//  App
//
//  Created by Oguz Sutanrikulu on 10.12.19.
//

import Foundation
import Vapor
import ZIPFoundation
import SwiftLintFramework

class BitBucketService: SourceControlServable {
    
    let project: LicoreProject
    let scmSystem: SourceControlManagementSystem
    
    init(project: LicoreProject, scmSystem: SourceControlManagementSystem) {
        self.project = project
        self.scmSystem = scmSystem
    }
    
    func downloadSources(pullRequest: PullRequest, req: Request, completion: @escaping () -> Void) {
        Repository.find(pullRequest.$repository.id, on: req.db).whenSuccess { repository in
            guard let repository = repository else { return }
            let uri = URI(string: "\(self.scmSystem.scmURL)/rest/api/1.0/projects/\(self.project.key)/repos/\(repository.name)/archive?filename=sourceFiles.zip&at=\(pullRequest.latestCommit)")
            let headers = HTTPHeaders(dictionaryLiteral:
                ("Authorization", "Basic \(self.scmSystem.token)"),
                                      ("Content-Type", "application/json")
            )
            
            logger.info("Downloading Sources from: \(uri)")
            
            do {
                req.client.get(uri, headers: headers, beforeSend: { _ in
                }).flatMapThrowing { response in
                    let responseData = response.body?.withUnsafeReadableBytes {
                        Data($0)
                    }
                    guard let data = responseData else { return }
                    
                    self.saveDataToFile(fileName: "sourceFiles", fileExtension: ".zip", commitHash: pullRequest.latestCommit, data: data)
                    completion()
                }
            }
        }
    }
    
    // Sets a Webhook for a given Repository
    public func hookRepository(project: LicoreProject,
                               repositoryName: String,
                               hookURL: String,
                               req: Request) -> EventLoopFuture<HTTPStatus> {
        let url = URI(string: "\(scmSystem.scmURL)/rest/api/1.0/projects/\(project.key)/repos/\(repositoryName)/webhooks")
        let headers = HTTPHeaders(dictionaryLiteral:
            ("Authorization", "Basic \(scmSystem.token)"),
                                  ("Content-Type", "application/json;charset=utf-8")
        )
        
        let events = ["pr:opened",
                      "repo:refs_changed",
                      "pr:reviewer:approved",
                      "pr:reviewer:needs_work"]
        
        let hookBody = BitBucketWebhookRequest(name: project.name + "_" + repositoryName + "_webhook",
                                               events: events,
                                               url: hookURL)
        
        do {
            return req.client.post(url, headers: headers, beforeSend: { req in
                try req.content.encode(hookBody)
            }).flatMapThrowing { response in
                logger.info("\(response)")
                return response.status
            }
        }
    }
    
    // Fetches all Repositories of a given Project
    public func getRepositories(req: Request) -> EventLoopFuture<[Repository]> {
        logger.info("Getting Repositories for Project: \(project.key)")
        
        let url = URI(string: "\(scmSystem.scmURL)/rest/api/1.0/projects/\(project.key)/repos?limit=1000")
        let headers = HTTPHeaders(dictionaryLiteral:
            ("Authorization", "Basic \(scmSystem.token)"),
                                  ("Content-Type", "application/json;charset=utf-8")
        )
        
        do {
            return req.client.get(url, headers: headers, beforeSend: { _ in
            }).flatMapThrowing { respones in
                return try respones.content.get([BitBucketRepositoryResponse].self, at: "values").compactMap { response in
                    return response.createLicoreModel()
                }
            }
        }
    }
    
    public func getDevelopers(repositoryName: String, req: Request) -> EventLoopFuture<[Developer]> {
        logger.info("Getting Developers for Project: \(project.key) & Repository: \(repositoryName)")
        
        let url = URI(string: "\(scmSystem.scmURL)/rest/api/1.0/projects/\(project.key)/repos/\(repositoryName)/permissions/users?limit=1000")
        let headers = HTTPHeaders(dictionaryLiteral:
            ("Authorization", "Basic \(scmSystem.token)"),
                                  ("Content-Type", "application/json")
        )
        
        do {
            return req.client.get(url, headers: headers, beforeSend: { _ in
            }).flatMapThrowing { responses in
                return try responses.content.get([BitBucketUserResponse].self, at: "values").compactMap { responses in
                    return responses.user.createLicoreModel()
                }
            }
        }
    }
    
    // Fetches all PullRequests of a given Repository
    public func getPullRequests(repositoryName: String, req: Request) -> EventLoopFuture<[PullRequest]> {
        logger.info("Getting Pull Requests for Project: \(project.key) & Repository: \(repositoryName)")
        
        let url = URI(string: "\(scmSystem.scmURL)/rest/api/1.0/projects/\(project.key)/repos/\(repositoryName)/pull-requests?state=OPEN&limit=1000")
        let headers = HTTPHeaders(dictionaryLiteral:
            ("Authorization", "Basic \(scmSystem.token)"),
                                  ("Content-Type", "application/json")
        )
        
        do {
            return req.client.get(url, headers: headers, beforeSend: { _ in
            }).flatMapThrowing { responses in
                return try responses.content.get([BitBucketPullRequestResponse].self, at: "values").compactMap { responses in
                    return responses.createLicoreModel()
                }
            }
        }
    }
    
    // Fetches data of the given PullRequest
    public func getPullRequest(repositoryName: String, pullRequestId: Int, req: Request) -> EventLoopFuture<PullRequest?> {
        logger.info("Getting Pull Request for Project: \(project.key) & Repository: \(repositoryName) with the ID: \(pullRequestId)")
        
        let url = URI(string: "\(scmSystem.scmURL)/rest/api/1.0/projects/\(project.key)/repos/\(repositoryName)/pull-requests/\(pullRequestId.description)")
        let headers = HTTPHeaders(dictionaryLiteral:
            ("Authorization", "Basic \(scmSystem.token)"),
                                  ("Content-Type", "application/json")
        )
        
        do {
            return req.client.get(url, headers: headers, beforeSend: { _ in
            }).flatMapThrowing { responses in
                return try responses.content.decode(BitBucketPullRequestResponse.self).createLicoreModel()
            }
        }
    }
    
    // Fetches the diff of the given PullRequest
    public func getDiff(repositoryName: String, pullRequestId: Int, req: Request) -> EventLoopFuture<Diff> {
        logger.info("Getting Diff for Pull Request with the ID: \(pullRequestId) for Project: \(project.key) & Repository: \(repositoryName)")
        
        let uri = URI(string: "\(scmSystem.scmURL)/rest/api/1.0/projects/\(project.key)/repos/\(repositoryName)/pull-requests/\(pullRequestId.description)/diff")
        let headers = HTTPHeaders(dictionaryLiteral:
            ("Authorization", "Basic \(scmSystem.token)"),
                                  ("Content-Type", "application/json")
        )
        
        do {
            return req.client.get(uri, headers: headers, beforeSend: { _ in
            }).flatMapThrowing { response in
                do {
                    return try response.content.decode(BitBucketDiffResponse.self).createLicoreModel()
                }
            }
        }
    }
    
    // Fetches all comments from the given PullRequest
    public func getComments(repositoryName: String, pullRequestId: Int, req: Request) -> EventLoopFuture<[Comment]> {
        logger.info("Getting Comments for Pull Request with the ID: \(pullRequestId) for Project: \(project.key) & Repository: \(repositoryName)")
        
        let url = URI(string: "\(scmSystem.scmURL)/rest/api/1.0/projects/\(project.key)/repos/\(repositoryName)/pull-requests/\(pullRequestId.description)/activities?limit=10000")
        let headers = HTTPHeaders(dictionaryLiteral:
            ("Authorization", "Basic \(scmSystem.token)"),
                                  ("Content-Type", "application/json")
        )
        
        do {
            return req.client.get(url, headers: headers, beforeSend: { _ in
            }).flatMapThrowing { responses in
                return try responses.content.get([BitBucketActivityResponse].self, at: "values").filter { activity in
                    activity.action == "COMMENTED" && activity.comment?.author.slug == "swiftlint"
                }.compactMap { activity in
                    return activity.comment?.createLicoreModel()
                }
            }
        }
    }
    
    // Add Comment to a PullRequest
    public func postComment(repositoryName: String,
                            pullRequest: PullRequest,
                            comment: Comment,
                            diff: Diff,
                            req: Request) -> EventLoopFuture<HTTPStatus> {
        logger.info("Posting Comment for Pull Request with the ID: \(pullRequest.scmId) for Project: \(project.key) & Repository: \(repositoryName)")
        
        let url = URI(string: "\(scmSystem.scmURL)/rest/api/1.0/projects/\(project.key)/repos/\(repositoryName)/pull-requests/\(pullRequest.scmId.description)/comments")
        let headers = HTTPHeaders(dictionaryLiteral:
            ("Authorization", "Basic \(scmSystem.token)"),
                                  ("Content-Type", "application/json")
        )
        
        let anchor = CommentAnchor(fromHash: diff.fromRef,
                                   toHash: diff.toRef,
                                   line: comment.line ?? 0,
                                   lineType: "ADDED",
                                   filetype: "TO",
                                   path: comment.path ?? "",
                                   diffType: "EFFECTIVE")
        let text = "\(comment.violationIcon) \(comment.violationTypeName)\n" + "[\(comment.ruleDescription)] " + "At line \(comment.line?.description ?? "0"): " + "\(comment.content)"
        let taskRequest = BitBucketCommentRequest(anchor: anchor, text: text)
        
        do {
            return req.client.post(url, headers: headers, beforeSend: { req in
                try req.content.encode(taskRequest)
            }).flatMapThrowing { responses in
                return responses.status
            }
        }
    }
    
    // Add Comment to a PullRequest
    public func postGeneralComment(repositoryName: String,
                                   pullRequest: PullRequest,
                                   comments: [Comment],
                                   req: Request) -> EventLoopFuture<HTTPStatus> {
        logger.info("Posting General Comment for Pull Request with the ID: \(pullRequest.scmId) for Project: \(project.key) & Repository: \(repositoryName)")
        
        let url = URI(string: "\(scmSystem.scmURL)/rest/api/1.0/projects/\(project.key)/repos/\(repositoryName)/pull-requests/\(pullRequest.scmId.description)/comments")
        let headers = HTTPHeaders(dictionaryLiteral:
            ("Authorization", "Basic \(scmSystem.token)"),
                                  ("Content-Type", "application/json")
        )
        
        var text = "General Findings: \n"
        
        for comment in comments {
            text.append("\(comment.violationIcon) \(comment.violationTypeName)\n" + "[\(comment.ruleDescription)] " + "\(comment.content)\n")
        }
        
        do {
            return req.client.post(url, headers: headers, beforeSend: { req in
                try req.content.encode(text)
            }).flatMapThrowing { responses in
                return responses.status
            }
        }
    }
    
    public func getTasks(repositoryName: String, pullRequest: PullRequest, req: Request) -> EventLoopFuture<[Task?]> {
        logger.info("Getting Tasks for Pull Request with the ID: \(pullRequest.scmId) for Project: \(project.key) & Repository: \(repositoryName)")
        
        let url = URI(string: "\(scmSystem.scmURL)/rest/api/1.0/projects/\(project.key)/repos/\(repositoryName)/pull-requests/\(pullRequest.scmId)/tasks")
        let headers = HTTPHeaders(dictionaryLiteral:
            ("Authorization", "Basic \(scmSystem.token)"),
                                  ("Content-Type", "application/json")
        )
        
        do {
            return req.client.get(url, headers: headers, beforeSend: { _ in
            }).flatMapThrowing { responses in
                do {
                    let tasks = try JSONDecoder().decode(BitBucketTasksResponse.self, from: responses.body!, headers: responses.headers)
                    let botTaskValues = tasks.values?.filter { $0.author?.slug == "swiftlint" }
                    guard let values = botTaskValues else { return [] }
                    
                    return values.map { value in
                        return value.createLicoreModel()
                    }
                }
            }
        }
    }
    
    public func postTasks(repositoryName: String,
                          pullRequest: PullRequest,
                          tasks: [Task],
                          req: Request) -> EventLoopFuture<HTTPStatus> {
        logger.info("Posting Tasks for Pull Request with the ID: \(pullRequest.scmId) for Project: \(project.key) & Repository: \(repositoryName)")
        
        let url = URI(string: "\(scmSystem.scmURL)/rest/api/1.0/projects/\(project.key)/repos/\(repositoryName)/pull-requests/\(pullRequest.scmId)/comments")
        let headers = HTTPHeaders(dictionaryLiteral:
            ("Authorization", "Basic \(scmSystem.token)"),
                                  ("Content-Type", "application/json")
        )
        
        let text = ["text": "Tasks: \n"]
        
        do {
            return req.client.post(url, headers: headers, beforeSend: { req in
                try req.content.encode(text)
            }).flatMapThrowing { responses in
                let commentId = try responses.content.decode(BitBucketCommentResponse.self).id
                self.postTasksToComment(commentId: commentId, tasks: tasks, req: req)
                
                return responses.status
            }
        }
    }
    
    public func postTasksToComment(commentId: Int, tasks: [Task], req: Request) {
        logger.info("Posting Tasks to Comment with the ID: \(commentId)")
        
        let url = URI(string: "\(scmSystem.scmURL)/rest/api/1.0/tasks")
        let headers = HTTPHeaders(dictionaryLiteral:
            ("Authorization", "Basic \(scmSystem.token)"),
                                  ("Content-Type", "application/json")
        )
        
        for task in tasks {
            let anchor = TaskAnchor(id: commentId, type: "COMMENT")
            let text = "Fix " + task.occurence.description + " [" + task.description + "]" + " issue(s).\n"
            let taskRequest = BitBucketTaskRequest(anchor: anchor, text: text, state: task.resolved == true ? "RESOLVED" : "OPEN")
            
            do {
                req.client.post(url, headers: headers, beforeSend: { req in
                    try req.content.encode(taskRequest)
                })
            }
        }
    }
    
    public func resolveTask(id: Int, req: Request) -> EventLoopFuture<HTTPStatus> {
        logger.info("Resoling Task with the ID: \(id)")
        
        let url = URI(string: "\(scmSystem.scmURL)/rest/api/1.0/tasks/\(id.description)")
        let headers = HTTPHeaders(dictionaryLiteral:
            ("Authorization", "Basic \(scmSystem.token)"),
                                  ("Content-Type", "application/json")
        )
        
        let task = ["id": id.description,
                    "state": "RESOLVED"
        ]
        
        do {
            return req.client.put(url, headers: headers, beforeSend: { req in
                try req.content.encode(task)
            }).flatMapThrowing { response in
                return response.status
            }
        }
    }
    
    public func deleteAllComments(repositoryName: String, pullRequestId: Int, req: Request) {
        logger.info("Deleting All Comments for Pull Request with the ID: \(pullRequestId)")
        
        self.getComments(repositoryName: repositoryName, pullRequestId: pullRequestId, req: req).whenSuccess { comments in
            comments.map { comment in
                guard let commentID = comment.id else {
                    logger.warning("Comment not found!")
                    return
                }
                
                let version = comment.version ?? -1
                
                let url = URI(string: "\(self.scmSystem.scmURL)/rest/api/1.0/projects/\(self.project.key)/repos/\(repositoryName)/pull-requests/\(pullRequestId)/comments/\(commentID)?version=\(version)")
                let headers = HTTPHeaders(dictionaryLiteral:
                    ("Authorization", "Basic \(self.scmSystem.token)"),
                                          ("Content-Type", "application/json")
                )
                
                do {
                    req.client.delete(url, headers: headers, beforeSend: { _ in
                    })
                }
            }
        }
    }
    
    // Sets Status for a PullRequest
    public func approvePullRequest(repositoryName: String, pullRequest: PullRequest, req: Request) -> EventLoopFuture<HTTPStatus> {
        logger.info("Approving Pull Request with the ID: \(pullRequest.scmId) for Project: \(project.key) & Repository: \(repositoryName)")
        
        let url = URI(string: "\(scmSystem.scmURL)/rest/api/1.0/projects/\(project.key)/repos/\(repositoryName)/pull-requests/\(pullRequest.scmId)/participants/SwiftLint")
        let headers = HTTPHeaders(dictionaryLiteral:
            ("Authorization", "Basic \(self.scmSystem.token)"),
                                  ("Content-Type", "application/json")
        )
        
        let status = ["status": "APPROVED"]
        
        do {
            return req.client.put(url, headers: headers, beforeSend: { req in
                try req.content.encode(status)
            }).flatMapThrowing { responses in
                return responses.status
            }
        }
    }
    
    // Sets Status for a PullRequest
    public func markNeedsRework(repositoryName: String, pullRequest: PullRequest, req: Request) -> EventLoopFuture<HTTPStatus> {
        logger.info("Posting Comment for Pull Request with the ID: \(pullRequest.scmId) for Project: \(project.key) & Repository: \(repositoryName)")
        
        let url = URI(string: "\(scmSystem.scmURL)/rest/api/1.0/projects/\(project.key)/repos/\(repositoryName)/pull-requests/\(pullRequest.scmId)/participants/SwiftLint")
        let headers = HTTPHeaders(dictionaryLiteral:
            ("Authorization", "Basic \(self.scmSystem.token)"),
                                  ("Content-Type", "application/json")
        )
        
        let status = ["status": "NEEDS_WORK"]
        
        do {
            return req.client.put(url, headers: headers, beforeSend: { req in
                try req.content.encode(status)
            }).flatMapThrowing { responses in
                return responses.status
            }
        }
    }
}

extension BitBucketService {
    func saveDataToFile(fileName: String,
                        fileExtension: String,
                        commitHash: String,
                        data: Data) {
        let dirs = DirectoryConfiguration.self
        let path = dirs.detect().workingDirectory
        
        let shortHash = commitHash.prefix(8)
        
        let fileURL = URL(fileURLWithPath: path + "sources_" + shortHash + "/" + fileName + fileExtension)
        logger.info("Writing Data to File: \(fileURL)")
        
        do {
            try data.write(to: fileURL)
        } catch {
            logger.warning("Could not write data to disk!")
        }
    }
}
