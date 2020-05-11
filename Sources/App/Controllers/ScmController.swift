//
//  ScmController.swift
//  App
//
//  Created by Oguz Sutanrikulu on 21.03.20.
//

import Vapor
import Leaf

struct ScmController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        routes.get("scms", use: allScms)
        routes.get("scms", ":id", use: scmConfigUpdate)
        routes.post("scms", ":id") { req -> EventLoopFuture<Response> in
            let context = try req.content.decode(ScmPostCreateContext.self)
            
            return self.scmPostUpdate(req: req, context: context).transform(to: req.redirect(to: "/scms"))
        }
        
        routes.post("scms", ":id", "remove") { req -> EventLoopFuture<Response> in
            return self.removeScm(req: req).transform(to: req.redirect(to: "/scms"))
        }
        
        routes.get("createScm", use: scmConfigCreate)
        routes.post("createScm") { req -> EventLoopFuture<Response> in
            let context = try req.content.decode(ScmPostCreateContext.self)
            
            return self.scmPostCreate(req: req, context: context).transform(to: req.redirect(to: "/createScm"))
        }
    }
    
    func allScms(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        return SourceControlManagementSystem.query(on: req.db).all().flatMap { scms in
            let context = ScmSystemsContext(scmSystems: scms)
            
            return req.view.render("scmsTable", context)
        }
    }
    
    func scmConfigCreate(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        return req.view.render("scmConfig")
    }
    
    func scmConfigUpdate(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        guard let scmParameter = req.parameters.get("id") else { return req.view.render("scms") }
        guard let scmId = Int(scmParameter) else { return req.view.render("scms") }
        
        return SourceControlManagementSystem.find(scmId, on: req.db).flatMap { scm in
            return req.view.render("scmConfigUpdate", scm)
        }
    }
    
    func scmPostCreate(req: Request, context: ScmPostCreateContext) -> EventLoopFuture<HTTPStatus> {
        let scmSystem = SourceControlManagementSystem(name: context.name,
                                                      scmType: context.scmType,
                                                      scmURL: context.scmURL,
                                                      token: basic(name: context.username,
                                                                   password: context.password))
        
        return scmSystem.save(on: req.db).transform(to: .ok)
    }
    
    func scmPostUpdate(req: Request, context: ScmPostCreateContext) -> EventLoopFuture<HTTPStatus> {
        guard let scmParameter = req.parameters.get("id") else { return req.eventLoop.future(.internalServerError) }
        guard let scmId = Int(scmParameter) else { return req.eventLoop.future(.internalServerError) }
        
        return SourceControlManagementSystem.find(scmId, on: req.db).flatMap { scm in
            guard let scm = scm else { return req.eventLoop.future(.internalServerError) }
            
            scm.name = context.name
            scm.scmType = context.scmType
            scm.scmURL = context.scmURL
            
            if context.username != "" || context.password != "" {
                scm.token = basic(name: context.username,
                                  password: context.password)
            }
            
            return scm.update(on: req.db).transform(to: .ok)
        }
    }
    
    func removeScm(req: Request) -> EventLoopFuture<HTTPStatus> {
        guard let scmParameter = req.parameters.get("id") else { return req.eventLoop.future(.internalServerError) }
        guard let scmId = Int(scmParameter) else { return req.eventLoop.future(.internalServerError) }
        
        return SourceControlManagementSystem.find(scmId, on: req.db).flatMap { scmSystem in
            guard let scmSystem = scmSystem else { return req.eventLoop.future(.internalServerError) }
            
            return scmSystem.delete(on: req.db).transform(to: .ok)
        }
    }
    
}

struct ScmSystemsContext: Content {
    let scmSystems: [SourceControlManagementSystem]
}

struct ScmPostCreateContext: Content {
    let name: String
    let scmType: SourceControlType
    let scmURL: String
    let username: String
    let password: String
}
