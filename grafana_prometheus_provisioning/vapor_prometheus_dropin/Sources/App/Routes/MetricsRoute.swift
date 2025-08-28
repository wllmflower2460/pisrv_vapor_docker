// Sources/App/Routes/MetricsRoute.swift
// Exposes /metrics for Prometheus to scrape.

import Vapor

func registerMetricsRoute(_ app: Application) {
    app.get("metrics") { req async throws -> String in
        try await PrometheusMetrics.client.collect()
    }
}
