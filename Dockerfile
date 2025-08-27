# Vapor-only, multi-stage, ARM64-friendly
FROM swift:5.9.1-jammy AS builder
WORKDIR /build

# Cache deps
COPY Package.swift Package.resolved ./
RUN swift package resolve

# Build
COPY Sources ./Sources
COPY Tests ./Tests  
# If you have these, uncomment:
# COPY Resources ./Resources
# COPY Public ./Public

RUN swift build -c release

FROM swift:5.9.1-jammy-slim AS runtime
WORKDIR /app

# minimal runtime deps (remove libsqlite3-0 if not using SQLite)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl tzdata ca-certificates libsqlite3-0 libatomic1 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/.build/release/Run /app/Run

ENV SESSIONS_DIR=/var/app/sessions
RUN mkdir -p "$SESSIONS_DIR"

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -fsS http://localhost:8080/healthz || exit 1

ENTRYPOINT ["/app/Run", "serve", "--hostname", "0.0.0.0", "--port", "8080"]
