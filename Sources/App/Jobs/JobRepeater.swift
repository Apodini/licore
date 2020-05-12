//
//  JobRepeater.swift
//  App
//
//  Created by Oguz Sutanrikulu on 26.01.20.
//

import Vapor
import Queues

public struct JobRepeater: ScheduledJob {
    
    let app: Application
    
    public func run(context: QueueContext) -> EventLoopFuture<Void> {
        app.queues.queue.worker.run()
        
        return context.eventLoop.future()
    }
}
