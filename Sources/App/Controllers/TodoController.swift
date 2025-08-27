import Vapor
import Fluent

/// Controller for managing Todo items
struct TodoController {
    /// GET /todos
    func index(req: Request) throws -> EventLoopFuture<[Todo]> {
        Todo.query(on: req.db).all()
    }

    /// POST /todos
    func create(req: Request) throws -> EventLoopFuture<Todo> {
        let todo = try req.content.decode(Todo.self)
        return todo.save(on: req.db).map { todo }
    }

    /// GET /todos/:todoID
    func getOne(req: Request) throws -> EventLoopFuture<Todo> {
        guard let id = req.parameters.get("todoID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        return Todo.find(id, on: req.db)
            .unwrap(or: Abort(.notFound))
    }

    /// PATCH /todos/:todoID
    func update(req: Request) throws -> EventLoopFuture<Todo> {
        guard let id = req.parameters.get("todoID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        let updated = try req.content.decode(Todo.self)
        return Todo.find(id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { existing in
                existing.title = updated.title
                existing.completed = updated.completed
                return existing.update(on: req.db).map { existing }
            }
    }

    /// DELETE /todos/:todoID
    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let id = req.parameters.get("todoID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        return Todo.find(id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { $0.delete(on: req.db) }
            .transform(to: .noContent)
    }
}
