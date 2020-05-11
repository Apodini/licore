//
//  AuthController.swift
//  App
//
//  Created by Oguz Sutanrikulu on 16.01.20.
//

import Vapor
import Leaf

struct AuthController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        routes.get(use: index)
        
        routes.get("login", use: licoreLogin)
        routes.post("login") { req -> EventLoopFuture<Response> in
            let loginData = try req.content.decode(LoginPostDataContext.self)

            return self.licorePostLogin(req: req, context: loginData)
        }
        
        routes.get("licoreUser", use: updateLicoreUser)
        routes.post("licoreUser") { req -> EventLoopFuture<Response> in
            guard req.hasSession else {
                return req.eventLoop.future(req.redirect(to: "login"))
            }
            
            let context = try req.content.decode(UpdateLicoreUserContext.self)
            
            return self.licoreUpdateUser(req: req, context: context)
        }
        
        routes.post("logout") { req -> EventLoopFuture<Response> in
            return self.licorePostLogout(req: req)
        }
        
    }
    
    func index(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        return LicoreProject.query(on: req.db).with(\.$scmSystem).all().flatMap { projects in
            let context = IndexContext(title: "All Projects", projects: projects)
            
            return req.view.render("index", context)
        }
    }
    
    func updateLicoreUser(req: Request) -> EventLoopFuture<View> {
        guard req.hasSession else {
            return req.view.render("login")
        }
        
        return LicoreUser.query(on: req.db).first().flatMap { licoreUser in
            guard let licoreUser = licoreUser else {
                return req.view.render("login")
            }
            
            let context = UpdateLicoreUserContext(username: licoreUser.name, email: licoreUser.email, password: "", confirmPassword: "")
            
            return req.view.render("updateUser", context)
        }
    }
    
    func licoreUpdateUser(req: Request, context: UpdateLicoreUserContext) -> EventLoopFuture<Response> {
        return LicoreUser.query(on: req.db).first().flatMapThrowing { licoreUser in
            guard let licoreUser = licoreUser else {
                return req.redirect(to: "login")
            }
            
            guard context.password == context.confirmPassword else {
                return req.redirect(to: "login")
            }
            
            licoreUser.name = context.username
            licoreUser.passwordHash = try Bcrypt.hash(context.password)
            licoreUser.email = context.email
            
            licoreUser.update(on: req.db)
            return req.redirect(to: "projects")
        }
    }
    
    func licoreLogin(req: Request) -> EventLoopFuture<View> {
        let context: LoginContext
        
        if req.query[Bool.self, at: "error"] != nil {
            context = LoginContext(loginError: true)
        } else {
            context = LoginContext()
        }
        
        return req.view.render("login", context)
    }
    
    func licorePostLogin(req: Request, context: LoginPostDataContext) -> EventLoopFuture<Response> {
        let basic = BasicAuthorization(username: context.username, password: context.password)

        return LicoreUser.query(on: req.db).first().flatMapThrowing { licoreUser -> Response in
            guard let licoreUser = licoreUser else {
                logger.error("Licore User does not exist!")
                return req.redirect(to: "login")
            }
            
            do {
                if try licoreUser.verify(password: context.password) {
                    req.session.authenticate(licoreUser)
                    return req.redirect(to: "projects")
                } else {
                    logger.error("Could not verify password!")
                    return req.redirect(to: "login")
                }
            }
        }
    }
    
    func licorePostLogout(req: Request) -> EventLoopFuture<Response> {
        req.session.unauthenticate(LicoreUser.self)
        req.session.destroy()
        
        return req.eventLoop.future(req.redirect(to: "login"))
    }
    
}

struct UpdateLicoreUserContext: Content {
    let username: String
    let email: String
    let password: String
    let confirmPassword: String
}

struct LoginPostDataContext: Content {
    let username: String
    let password: String
}

struct IndexContext: Encodable {
    let title: String
    let projects: [LicoreProject]
}

struct LoginContext: Encodable {
    let title = "Log In"
    let loginError: Bool
    
    init(loginError: Bool = false) {
        self.loginError = loginError
    }
}

func basic(name: String, password: String) -> String {
    guard let basic = (name + ":" + password).data(using: .utf8)?.base64EncodedString() else {
        return ""
    }
    return basic
}
