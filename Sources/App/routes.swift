import Fluent
import Vapor

func routes(_ app: Application) throws {
    
    let webhooksController = WebhooksController()
    let authController = AuthController()
    let reviewersController = ReviewersController()
    let reposController = ReposController()
    let projectsController = ProjectsController()
    let scmController = ScmController()
    let jobsController = JobsController()
    let pullRequestsController = PullRequestsController()

    try app.routes.register(collection: authController)
    try app.routes.register(collection: webhooksController)
    try app.routes.register(collection: reviewersController)
    try app.routes.register(collection: reposController)
    try app.routes.register(collection: projectsController)
    try app.routes.register(collection: scmController)
    try app.routes.register(collection: jobsController)
    try app.routes.register(collection: pullRequestsController)
    
    app.get("ping") { _ in
        return "pong"
    }
    
    return
    
}

extension RoutesBuilder {
    @discardableResult
    public func upload<Response>(
        _ path: PathComponent...,
        use closure: @escaping (Request) throws -> Response
    ) -> Route
        where Response: ResponseEncodable {
        return self.on(.POST, path, body: .collect(maxSize: 10_000_000), use: closure)
    }
    
    @discardableResult
    public func upload<Response>(
        _ path: [PathComponent],
        use closure: @escaping (Request) throws -> Response
    ) -> Route
        where Response: ResponseEncodable {
        return self.on(.POST, path, body: .collect(maxSize: 10_000_000), use: closure)
    }
}
