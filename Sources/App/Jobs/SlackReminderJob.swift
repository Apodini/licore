//
//  SlackReminderJob.swift
//  App
//
//  Created by Oguz Sutanrikulu on 09.03.20.
//

import Vapor
import Queues
import Fluent

public struct SlackReminderJob: ScheduledJob {
    
    let req: Request
    
    func run(context: QueueContext) -> EventLoopFuture<Void> {
        logger.info("Running Slack Reminder Job")
        
        let slackService = SlackService()
        
        LicoreProject.query(on: req.db).with(\.$repositories) {
            $0.with(\.$pullRequests)
            $0.with(\.$developers)
        }.all().map { projects in
            projects.forEach { project in
                guard let slackToken = project.slackToken else { return }
                
                project.repositories.forEach { repository in
                    project.sourceControlService(req: self.req).whenSuccess { sourceControlService in
                        
                        guard let sourceControlService = sourceControlService else {
                            logger.error("Source Control Service could not be loaded!")
                            return
                        }
                        
                        sourceControlService.getPullRequests(repositoryName: repository.name, req: self.req).whenSuccess { pullRequests in
                            pullRequests.forEach { pullRequest in
                                print("Creation Date: " + pullRequest.creationDate.description)
                                
                                let now = Date().timeIntervalSince1970
                                let prCreationDate = pullRequest.creationDate / 1000
                                
                                if (now - prCreationDate) > 86400 {
                                    guard let developer = repository.developers.first else { return }
                                    
                                    slackService.getSlackUser(req: self.req, by: developer.email, token: slackToken).whenSuccess { slackUser in
                                        guard let slackUser = slackUser else { return }
                                        SourceControlManagementSystem.find(project.$scmSystem.id, on: self.req.db).map { scmSystem in
                                            guard let scmSystem = scmSystem else { return }
                                            guard let reminderMessage = SlackReminderMessage(scmSystem: scmSystem,
                                                                                             project: project,
                                                                                             repository: repository,
                                                                                             pullRequest: pullRequest,
                                                                                             developer: developer).generateMessage else { return }
                                            
                                            slackService.postDirectMessage(req: self.req,
                                                                           to: slackUser.id,
                                                                           message: reminderMessage,
                                                                           token: slackToken)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return context.eventLoop.future()
    }
    
}

struct SlackReminderMessage: Content {
    let scmSystem: SourceControlManagementSystem
    let project: LicoreProject
    let repository: Repository
    let pullRequest: PullRequest
    let developer: Developer
    
    var generateMessage: String? {
        return "Hello \(developer.name.components(separatedBy: " ")[0]), you have an open pull request at: \(scmSystem.scmURL)/projects/\(project.key)/repos/\(repository.name)/pull-requests/\(pullRequest.scmId)/overview".addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
    }
}
