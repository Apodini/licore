//
//  SlackService.swift
//  App
//
//  Created by Oguz Sutanrikulu on 04.03.20.
//

import Foundation
import Vapor

///The `SlackService` can call `getSlackUser` to retrieve the Slack User ID by looking it up by email.
///It can post a direct message calling `postDirectMessage`.
public class SlackService {
    
    func getSlackUser(req: Request, by email: String, token: String) -> EventLoopFuture<SlackUser?> {
        logger.info("Getting User ID by E-Mail: \(email)")
        
        let url = URI(string: "https://slack.com/api/users.lookupByEmail?token=\(token)&email=\(email)")
        
        let client = req.client
        
        return client.get(url).flatMapThrowing { response in
            do {
                let slackUser = try response.content.get(SlackUser.self, at: "user")
                return slackUser
            } catch {
                logger.warning("Slack User not found!")
                return nil
            }
        }
    }
    
    func postDirectMessage(req: Request, to user: String, message: String, token: String) -> EventLoopFuture<HTTPStatus> {
        logger.info("Posting Direct Message to User: \(user) Message: \(message)")
        
        let url = URI(string: "https://slack.com/api/chat.postMessage?channel=\(user)&token=\(token)&text=\(message)")
        
        let client = req.client
        
        return client.post(url).flatMapThrowing { response in
            return response.status
        }
    }
    
}
