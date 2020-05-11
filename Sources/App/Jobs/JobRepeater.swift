//
//  JobRepeater.swift
//  App
//
//  Created by Oguz Sutanrikulu on 26.01.20.
//

import Vapor
import Queues

struct JobRepeater: ScheduledJob {
    
    let app: Application
    
    func run(context: QueueContext) -> EventLoopFuture<Void> {
        app.queues.queue.worker.run()
        
        return context.eventLoop.future()
    }
}
