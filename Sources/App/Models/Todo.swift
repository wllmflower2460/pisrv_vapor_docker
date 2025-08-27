import Fluent
import Vapor

/// Represents a single entry in a Todo list for Vapor 4
final class Todo: Model, Content {
    // MARK: - Schema name for the table
    static let schema = "todos"

    // MARK: - Fields
    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Field(key: "completed")
    var completed: Bool

    // MARK: - Initializers

    /// Creates an empty Todo (required by Fluent)
    init() { }

    /// Creates a new Todo
    init(id: UUID? = nil, title: String, completed: Bool = false) {
        self.id = id
        self.title = title
        self.completed = completed
    }
}

// Uncomment if you want to use Todo directly as a route parameter:
// extension Todo: Parameter {}

