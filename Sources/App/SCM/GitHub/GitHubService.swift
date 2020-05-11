//
//  GitHubService.swift
//  App
//
//  Created by Oguz Sutanrikulu on 18.12.19.
//

import Foundation
import Vapor

class GitHubService: SourceControlServable {

    let project: LicoreProject
    let scmSystem: SourceControlManagementSystem
    
    init(project: LicoreProject, scmSystem: SourceControlManagementSystem) {
        self.project = project
        self.scmSystem = scmSystem
    }
    
    func getDevelopers(repositoryName: String, req: Request) -> EventLoopFuture<[Developer]> {
        logger.info("Fetching Developers for Repository: \(repositoryName)")
        
        let url = URI(string: "\(scmSystem.scmURL)/repos/\(project.key)/\(repositoryName)/collaborators")
        let headers = HTTPHeaders(dictionaryLiteral:
                                 ("Authorization", "Basic \(self.scmSystem.token)"),
                                 ("User-Agent", "LI.CO.RE"),
                                 ("Accept", "application/json")
        )
        
        do {
            return req.client.get(url, headers: headers, beforeSend: { _ in
            }).flatMapThrowing { responses in
                return try responses.content.decode([GitHubCollaboratorsResponse].self).compactMap { responses in
                    return responses.createLicoreModel()
                }
            }
        }
    }
    
    func postComment(repositoryName: String,
                     pullRequest: PullRequest,
                     comment: Comment,
                     diff: Diff,
                     req: Request) -> EventLoopFuture<HTTPStatus> {
        logger.info("Posting Comment for Pull Request with the ID: \(pullRequest.scmId) for Project: \(project.key) & Repository: \(repositoryName)")
        
        let url = URI(string: "\(scmSystem.scmURL)/repos/\(project.key)/\(repositoryName)/commits/\(pullRequest.latestCommit)/comments")
        let headers = HTTPHeaders(dictionaryLiteral:
                                 ("Authorization", "Basic \(self.scmSystem.token)"),
                                 ("User-Agent", "LI.CO.RE"),
                                 ("Accept", "application/json")
        )
        
        let body = "\(comment.violationIcon) " + "\(comment.violationTypeName)\n" + " [\(comment.ruleDescription)] " + "At line \(comment.line?.description ?? "0"): " + "\(comment.content)"
        
        let path = String(comment.path?.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)[1] ?? "")
        let comment = GitHubCommentRequest(path: path,
                                           position: comment.line ?? 0,
                                           body: body)
        
        do {
            return req.client.post(url, headers: headers, beforeSend: { req in
                try req.content.encode(comment)
            }).flatMapThrowing { responses in
                return responses.status
            }
        }
    }
    
    func postGeneralComment(repositoryName: String,
                            pullRequest: PullRequest,
                            comments: [Comment],
                            req: Request) -> EventLoopFuture<HTTPStatus> {
        logger.info("Posting General Comments for Pull Request with the ID: \(pullRequest.scmId) for Project: \(project.key) & Repository: \(repositoryName)")
        
        let url = URI(string: "\(scmSystem.scmURL)/repos/\(project.key)/\(repositoryName)/commits/\(pullRequest.latestCommit)/comments")
        let headers = HTTPHeaders(dictionaryLiteral:
                                 ("Authorization", "Basic \(self.scmSystem.token)"),
                                 ("User-Agent", "LI.CO.RE"),
                                 ("Accept", "application/json")
        )
        
        var generalComments: [GitHubCommentRequest] = []
        
        comments.forEach { comment in
            let body = "\(comment.violationIcon) " + "\(comment.violationTypeName)\n" + " [\(comment.ruleDescription)] " + "At line \(comment.line?.description ?? "0"): " + "\(comment.content)"
            
            let path = ""
            generalComments.append(GitHubCommentRequest(path: path,
                                                        position: 0,
                                                        body: body))
        }
        
        for generalComment in generalComments {
            do {
                return req.client.post(url, headers: headers, beforeSend: { req in
                    try req.content.encode(generalComment)
                }).flatMapThrowing { responses in
                    return responses.status
                }
            }
        }
        return req.eventLoop.future(.ok)
    }
    
    func postTasks(repositoryName: String,
                   pullRequest: PullRequest,
                   tasks: [Task],
                   req: Request) -> EventLoopFuture<HTTPStatus> {
        logger.info("Posting Tasks for Pull Request with the ID: \(pullRequest.scmId) for Project: \(project.key) & Repository: \(repositoryName)")
        
        let url = URI(string: "\(scmSystem.scmURL)/repos/\(project.key)/\(repositoryName)/pulls/\(pullRequest.scmId)/reviews")
        let headers = HTTPHeaders(dictionaryLiteral:
                                 ("Authorization", "Basic \(self.scmSystem.token)"),
                                 ("User-Agent", "LI.CO.RE"),
                                 ("Accept", "application/json")
        )
        
        var body: String = ""
        
        for task in tasks {
            body.append("- [ ] Fix " + task.occurence.description + " [" + task.description + "]" + " issue(s).\n")
        }
        
        let commentBody = GitHubTopCommentRequest(body: body, event: "REQUEST_CHANGES")

        do {
            return req.client.post(url, headers: headers, beforeSend: { req in
                try req.content.encode(commentBody)
            }).flatMapThrowing { responses in
                return responses.status
            }
        }
    }
    
    func getDiff(repositoryName: String, pullRequestId: Int, req: Request) -> EventLoopFuture<Diff> {
        let url = URI(string: "https://api.github.com/repos/\(project.key)/\(repositoryName)/pulls/\(pullRequestId)")
        let headers = HTTPHeaders(dictionaryLiteral:
                                 ("Authorization", "Basic \(self.scmSystem.token)"),
                                 ("User-Agent", "LI.CO.RE"),
                                 ("Accept", "application/vnd.github.v3.diff")
        )
        
        do {
            return req.client.get(url, headers: headers, beforeSend: { _ in
            }).flatMapThrowing { response in
                
                guard let body = response.body else {
                    logger.error("Diff Response Body could not be loaded!")
                    return Diff(fromRef: "", toRef: "", diffs: [])
                }
                
                guard let pureDiff = body.getString(at: 0, length: body.readableBytes, encoding: .utf8) else {
                    logger.error("Diff Response Body could not be encoded in String!")
                    return Diff(fromRef: "", toRef: "", diffs: [])
                }
                
                guard let diffs = self.getMetaDataFromPureDiff(pureDiff: pureDiff) else {
                    return Diff(fromRef: "", toRef: "", diffs: [])
                }
                
                return Diff(fromRef: "", toRef: "", diffs: diffs)
                
            }
        }
    }
    
    func getMetaDataFromPureDiff(pureDiff: String) -> [Diffs]? {
        let allLines = pureDiff.components(separatedBy: .newlines)
        var lineByLine = allLines.dropFirst(4)
        lineByLine.append("EoF")
        
        var hunkLines: [String] = []
        var allHunkLines: [[String]] = []
        
        lineByLine.forEach { diffLine in
            
            if diffLine.contains("diff --git") || diffLine.contains("EoF") {
                hunkLines.append("EoF")
                allHunkLines.append(hunkLines)
                hunkLines = []
            }
            
            if diffLine.contains("+++") {
                hunkLines.append(diffLine)
            }
            
            if diffLine.contains("@@") {
                hunkLines.append(diffLine)
            }
            
            if (diffLine.prefix(1) == "+") && (diffLine.prefix(2) != "++") {
                hunkLines.append(diffLine)
            }
        }
        logger.info("Hunks Count: \(allHunkLines.count)")
        
        var diff: [Diffs] = []
        
        allHunkLines.forEach { hunkLines in
            var destination: Destination?
            var hunks: [Hunk] = []
            var lines: [Line] = []
            
            hunkLines.forEach { diffLine in
                
                if diffLine.contains("EoF") {
                    let newSegment = Segment(type: "ADDED", lines: lines)
                    
                    guard var hunk = hunks.first else { return }
                    hunk.segments?.append(newSegment)
                    hunks[0] = hunk
                    
                    diff.append(Diffs(destination: destination,
                                      hunks: hunks)
                    )
                }
                
                if diffLine.contains("+++") {
                    destination = Destination(toString: String(diffLine.suffix(diffLine.count - 6)))
                }
                
                if diffLine.contains("@@") {
                    let checkSpan = diffLine.components(separatedBy: "+")[1].contains(",")
                    let getSpan = diffLine.components(separatedBy: "+")[1].components(separatedBy: ",")[1].components(separatedBy: " ")[0]
                    
                    let destinationLine = diffLine.components(separatedBy: "+")[1].prefix(1)
                    let destinationSpan = checkSpan ? getSpan : "1"
                    
                    logger.info("Destination Line: \(destinationLine)")
                    logger.info("Destination Span: \(destinationSpan)")
                    hunks.append(Hunk(destinationLine: Int(destinationLine),
                                      destinationSpan: Int(destinationSpan),
                                      segments: []))
                }
                
                if (diffLine.prefix(1) == "+") && (diffLine.prefix(2) != "++") {
                    let destinationCount = lines.count ?? 0
                    lines.append(Line(line: String(diffLine.suffix(diffLine.count - 1)), destination: destinationCount))
                }
                
            }
        }
        return diff
    }
    
    func getBaseAndHead(repositoryName: String, pullRequestId: Int, req: Request) -> EventLoopFuture<GitHubPullRequestResponse> {
        let url = URI(string: "\(scmSystem.scmURL)/repos/\(project.key)/\(repositoryName)/pulls/\(pullRequestId.description)")
        let headers = HTTPHeaders(dictionaryLiteral:
                                 ("Authorization", "Basic \(self.scmSystem.token)"),
                                 ("User-Agent", "LI.CO.RE"),
                                 ("Accept", "application/json")
        )
        
        do {
            return req.client.get(url, headers: headers, beforeSend: { _ in
            }).flatMapThrowing { responses in
                return try responses.content.decode(GitHubPullRequestResponse.self)
            }
        }
    }
    
    
    func approvePullRequest(repositoryName: String, pullRequest: PullRequest, req: Request) -> EventLoopFuture<HTTPStatus> {
        logger.info("Approving Pull Request with the ID: \(pullRequest.scmId) for Project: \(project.key) & Repository: \(repositoryName)")
        
        let url = URI(string: "\(scmSystem.scmURL)/repos/\(project.key)/\(repositoryName)/statuses/\(pullRequest.latestCommit)")
        let headers = HTTPHeaders(dictionaryLiteral:
                                 ("Authorization", "Basic \(self.scmSystem.token)"),
                                 ("User-Agent", "LI.CO.RE"),
                                 ("Content-Type", "application/json")
        )

        let status = GitHubStatusRequest(state: "succes",
                                         context: "LI.CO.RE")

        do {
            return req.client.post(url, headers: headers, beforeSend: { req in
                try req.content.encode(status)
            }).flatMapThrowing { responses in
                return responses.status
            }
        }
    }
    
    func markNeedsRework(repositoryName: String, pullRequest: PullRequest, req: Request) -> EventLoopFuture<HTTPStatus> {
        logger.info("Pull Request with the ID: \(pullRequest.scmId) for Project: \(project.key) & Repository: \(repositoryName) needs rework!")
        
        let url = URI(string: "\(scmSystem.scmURL)/repos/\(project.key)/\(repositoryName)/statuses/\(pullRequest.latestCommit)")
        let headers = HTTPHeaders(dictionaryLiteral:
                                 ("Authorization", "Basic \(self.scmSystem.token)"),
                                 ("User-Agent", "LI.CO.RE"),
                                 ("Content-Type", "application/json")
        )

        let status = GitHubStatusRequest(state: "failure",
                                         context: "LI.CO.RE")

        do {
            return req.client.post(url, headers: headers, beforeSend: { req in
                try req.content.encode(status)
            }).flatMapThrowing { responses in
                return responses.status
            }
        }
    }
    
    func resolveTask(id: Int, req: Request) -> EventLoopFuture<HTTPStatus> {
        req.eventLoop.makeSucceededFuture(.ok)
    }
    
    func deleteAllComments(repositoryName: String, pullRequestId: Int, req: Request) {
        logger.info("Deleting All Comments for Pull Request with the ID: \(pullRequestId)")
        
        self.getComments(repositoryName: repositoryName, pullRequestId: pullRequestId, req: req).whenSuccess { comments in
            comments.forEach { comment in
                guard let commentID = comment.id else {
                    logger.warning("Comment not found!")
                    return
                }
                
                let url = URI(string: "\(self.scmSystem.scmURL)/repos/\(self.project.key)/\(repositoryName)/comments/\(commentID)?per_page=10000")
                let headers = HTTPHeaders(dictionaryLiteral:
                                         ("Authorization", "Basic \(self.scmSystem.token)"),
                                         ("User-Agent", "LI.CO.RE"),
                                         ("Content-Type", "application/json")
                )
                
                do {
                    req.client.delete(url, headers: headers, beforeSend: { _ in
                    })
                }
            }
        }
    }
    
    public func getTasks(repositoryName: String, pullRequest: PullRequest, req: Request) -> EventLoopFuture<[Task?]> {
        return req.eventLoop.future([])
    }
    
    func downloadSources(pullRequest: PullRequest, req: Request, completion: @escaping () -> Void) {
        logger.info("Downloading Sources for Commit: \(pullRequest.latestCommit)")
        
        Repository.find(pullRequest.$repository.id, on: req.db).whenSuccess { repository in
            guard let repository = repository else { return }
            
            let uri = URI(string: "https://codeload.github.com/\(self.project.key)/\(repository.name)/legacy.zip/\(pullRequest.latestCommit)")
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
    
    func hookRepository(project: LicoreProject,
                        repositoryName: String,
                        hookURL: String,
                        req: Request) -> EventLoopFuture<HTTPStatus> {
        let url = URI(string: "\(scmSystem.scmURL)/repos/\(project.key)/\(repositoryName)/hooks")
        let headers = HTTPHeaders(dictionaryLiteral:
                                 ("Authorization", "Basic \(self.scmSystem.token)"),
                                 ("User-Agent", "LI.CO.RE"),
                                 ("Accept", "application/json")
        )
        
        let hookBody = GitHubWebhookRequest(name: project.name + "_" + repositoryName + "_webhook",
                                            config: GitHubWebhookConfig(url: hookURL,
                                                                        contentType: "json"),
                                            events: ["push", "pull_request"])

        do {
            return req.client.post(url, headers: headers, beforeSend: { req in
                try req.content.encode(hookBody)
            }).flatMapThrowing { responses in
                return responses.status
            }
        }
    }
    
    func getRepositories(req: Request) -> EventLoopFuture<[Repository]> {
        let url = URI(string: "\(scmSystem.scmURL)/orgs/\(project.key)/repos")
        let headers = HTTPHeaders(dictionaryLiteral:
                                  ("Authorization", "Basic \(self.scmSystem.token)"),
                                  ("User-Agent", "LI.CO.RE"),
                                  ("Accept", "application/vnd.github.inertia-preview+json")
        )
        
        do {
            return req.client.get(url, headers: headers, beforeSend: { _ in
            }).flatMapThrowing { responses in
                return try responses.content.decode([GitHubRepositoryResponse].self).compactMap { response in
                    return response.createLicoreModel()
                }
                
            }
        }
    }
    
    func getComments(repositoryName: String, pullRequestId: Int, req: Request) -> EventLoopFuture<[Comment]> {
        let url = URI(string: "\(scmSystem.scmURL)/repos/\(project.key)/\(repositoryName)/comments")
        let headers = HTTPHeaders(dictionaryLiteral:
                                 ("Authorization", "Basic \(self.scmSystem.token)"),
                                 ("User-Agent", "LI.CO.RE"),
                                 ("Accept", "application/json")
        )
        
        do {
            return req.client.get(url, headers: headers, beforeSend: { _ in
            }).flatMapThrowing { responses in
                return try responses.content.decode([GitHubCommentResponse].self).compactMap { response in
                    return response.createLicoreModel()
                }
            }
        }
    }

    func getPullRequest(repositoryName: String, pullRequestId: Int, req: Request) -> EventLoopFuture<PullRequest?> {
        let url = URI(string: "\(scmSystem.scmURL)/repos/\(project.key)/\(repositoryName)/pulls/\(pullRequestId.description)")
        let headers = HTTPHeaders(dictionaryLiteral:
                                 ("Authorization", "Basic \(self.scmSystem.token)"),
                                 ("User-Agent", "LI.CO.RE"),
                                 ("Accept", "application/json")
        )
        
        do {
            return req.client.get(url, headers: headers, beforeSend: { _ in
            }).flatMapThrowing { responses in
                return try responses.content.decode(GitHubPullRequestResponse.self).createLicoreModel()
            }
        }
    }

    func getPullRequests(repositoryName: String, req: Request) -> EventLoopFuture<[PullRequest]> {
        let url = URI(string: "\(scmSystem.scmURL)/repos/\(project.key)/\(repositoryName)/pulls")
        let headers = HTTPHeaders(dictionaryLiteral:
                                 ("Authorization", "Basic \(self.scmSystem.token)"),
                                 ("User-Agent", "LI.CO.RE"),
                                 ("Accept", "application/json")
        )
        
        do {
            return req.client.get(url, headers: headers, beforeSend: { _ in
            }).flatMapThrowing { responses in
                return try responses.content.decode([GitHubPullRequestResponse].self).compactMap { response in
                    return response.createLicoreModel()
                }
            }
        }
    }
    
}

extension GitHubService {
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
