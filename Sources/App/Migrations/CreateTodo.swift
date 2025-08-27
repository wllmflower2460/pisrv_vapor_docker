import Fluent
import Vapor

/// Migration to create the `todos` table
struct CreateTodo: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Todo.schema)
            // Auto-incrementing primary key
            .id()
            // Title column: non-nullable string
            .field("title", .string, .required)
            // Completed column: non-nullable boolean with default false
            .field("completed", .bool, .required, .sql(.default(false)))
            .ignoreExisting() 
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Todo.schema).delete()
    }
}
