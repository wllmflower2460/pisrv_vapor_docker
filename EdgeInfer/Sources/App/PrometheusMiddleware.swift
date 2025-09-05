// Sources/App/Middleware/PrometheusMiddleware.swift
// Records comprehensive per-request metrics for Prometheus monitoring.

import Vapor

struct PrometheusMiddleware: AsyncMiddleware {
    func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let started = Date()
        
        // Update memory usage periodically
        Task.detached {
            let memInfo = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
            let result = withUnsafeMutablePointer(to: &memInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
                }
            }
            
            if result == KERN_SUCCESS {
                await PrometheusMetrics.shared.updateMemoryUsage(Double(memInfo.resident_size))
            }
        }
        
        do {
            let res = try await next.respond(to: req)
            await observe(req: req, status: res.status.code, started: started)
            return res
        } catch {
            let status = (error as? AbortError)?.status.code ?? HTTPStatus.internalServerError.code
            await observe(req: req, status: status, started: started)
            throw error
        }
    }

    private func observe(req: Request, status: UInt, started: Date) async {
        let elapsed = Date().timeIntervalSince(started) // seconds (Double)
        let method = req.method.rawValue.uppercased()
        let normalizedRoute = PrometheusMetrics.normalizedRoute(from: req.url.path)
        
        // Record comprehensive metrics
        await PrometheusMetrics.shared.recordRequest(
            method: method,
            route: normalizedRoute,
            status: Int(status),
            duration: elapsed
        )
        
        // Enhanced logging with performance context
        let statusClass = status >= 500 ? "ERROR" : (status >= 400 ? "WARN" : "INFO")
        req.logger.info("[\(statusClass)] \(method) \(normalizedRoute) -> \(status) (\(String(format: "%.3f", elapsed * 1000))ms)")
    }
}

// Helper for memory info
private struct mach_task_basic_info {
    var virtual_size: mach_vm_size_t = 0
    var resident_size: mach_vm_size_t = 0
    var resident_size_max: mach_vm_size_t = 0
    var user_time: time_value_t = time_value_t()
    var system_time: time_value_t = time_value_t()
    var policy: policy_t = 0
    var suspend_count: integer_t = 0
}
