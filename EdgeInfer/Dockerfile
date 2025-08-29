# Multi-stage ARM64-friendly build for EdgeInfer
FROM swift:5.10-jammy AS build

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libssl-dev \
    zlib1g-dev \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy package files first for dependency caching
COPY Package.swift Package.resolved* ./

# Resolve dependencies (cached layer)
RUN swift package resolve

# Copy source code
COPY Sources ./Sources

# Build the application
RUN swift build -c release --static-swift-stdlib

# Runtime stage - minimal Ubuntu with Hailo readiness
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libssl3 \
    libatomic1 \
    ca-certificates \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /run

# Copy the built binary
COPY --from=build /app/.build/release/EdgeInfer /run/EdgeInfer

# Create hailo mount point (ready for future integration)
RUN mkdir -p /opt/hailo

# Expose port
EXPOSE 8080

# Health check with generous Pi startup time  
HEALTHCHECK --interval=30s --timeout=10s --retries=5 --start-period=90s \
  CMD curl -f http://localhost:8080/healthz || exit 1

# Run the app
CMD ["/run/EdgeInfer", "serve", "--hostname", "0.0.0.0", "--port", "8080"]
