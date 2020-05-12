import Fluent
import FluentPostgresDriver
import Vapor
import Queues
import QueuesRedisDriver
import Leaf

var logger = Logger(label: "Licore Logger")

// Called before your application initializes.
func configure(_ app: Application) throws {
    
    logger.logLevel = .info
    
    let postgresHost = Environment.get("POSTGRESQL_HOSTNAME") ?? "licore_postgres"
    let postgresUser = Environment.get("POSTGRESQL_USER") ?? "postgres"
    let postgresPassword = Environment.get("POSTGRESQL_PASSWORD") ?? "postgres"
    let postgresDatabase = Environment.get("POSTGRESQL_DATABASE") ?? "db"
    
    logger.info("Connecting to the Postgres Database")
    app.databases.use(.postgres(hostname: postgresHost,
                                username: postgresUser,
                                password: postgresPassword,
                                database: postgresDatabase),
                      as: .psql)

    logger.info("Connecting to the Redis Database")
    let redisConfig = RedisConfiguration(hostname: Environment.get("REDIS_HOSTNAME") ?? "licore_redis",
                                         password: Environment.get("REDIS_PASSWORD") ?? "redis")
    
    logger.info("Setting Redis QueuesDriver")
    app.queues.use(custom: RedisQueuesDriver(configuration: redisConfig,
                                             on: app.eventLoopGroup))
    
    logger.info("Setting Hostname and Port")
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = 8080
    
    logger.info("Adding Review Job")
    let request = Request(application: app, on: app.eventLoopGroup.next())
    app.queues.add(ReviewJob(req: request))
    
    logger.info("Scheduling Jobs")
    app.queues.schedule(JobRepeater(app: app)).everySecond()
    app.queues.schedule(SlackReminderJob(req: request)).daily().at(7, 00)
    
    logger.info("Starting Scheduled Jobs")
    try QueuesCommand(application: app, scheduled: true).startScheduledJobs()
    
    logger.info("Configuring Leaf")
    app.views.use(.leaf)
    
    logger.info("Adding Migrations")
    app.migrations.add(LicoreConfig.LicoreConfigMigration(), to: .psql)
    app.migrations.add(LicoreUser.LicoreUserMigration(), to: .psql)
    app.migrations.add(UserToken.UserTokenMigration(), to: .psql)
    app.migrations.add(SourceControlManagementSystem.SourceControlManagementSystemMigration(), to: .psql)
    app.migrations.add(LicoreProject.LicoreProjectMigration(), to: .psql)
    app.migrations.add(Reviewer.ReviewerMigration(), to: .psql)
    app.migrations.add(ProjectReviewer.ProjectReviewerMigration(), to: .psql)
    app.migrations.add(Repository.RepostioryMigration(), to: .psql)
    app.migrations.add(RepositoryReviewer.RepositoryReviewerMigration(), to: .psql)
    app.migrations.add(Branch.BranchMigration(), to: .psql)
    app.migrations.add(Developer.DeveloperMigration(), to: .psql)
    app.migrations.add(RepositoryDeveloper.RepositoryDeveloperMigration(), to: .psql)
    app.migrations.add(PullRequest.PullRequestMigration(), to: .psql)
    app.migrations.add(StatusChange.StatusChangeMigration(), to: .psql)
    app.migrations.add(ReviewJobData.ReviewJobDataMigration(), to: .psql)
    app.migrations.add(ReviewStatistics.ReviewStatisticsMigration(), to: .psql)
    
    app.autoMigrate()
    
    logger.info("Starting the Sessions Middleware")
    let sessionsMiddleware = SessionsMiddleware(session: app.sessions.driver)
    app.middleware.use(sessionsMiddleware)
    
    logger.info("Looking for Licore User")
    Application.createDefaultUser(req: request)
    
    Application.getConfig(req: request).map { config in
        Application.hookURL = config?.hookURL ?? ""
        logger.info("Application URL loaded: \(Application.hookURL)")
    }
    
    try routes(app)
}

extension Application {
    static var hookURL = ""
}

extension Application {
    static func createDefaultUser(req: Request) -> EventLoopFuture<Void> {
        return LicoreUser.query(on: req.db).first().flatMapThrowing { licoreUser in
            guard licoreUser == nil else {
                return
            }
            
            let user = try LicoreUser(
                name: "Licore",
                email: " ",
                passwordHash: Bcrypt.hash("licore")
            )
            
            user.save(on: req.db)
        }
    }
    
    static func getConfig(req: Request) -> EventLoopFuture<LicoreConfig?> {
        return LicoreConfig.query(on: req.db).all().map { configs in
            return configs.last
        }
    }
}
