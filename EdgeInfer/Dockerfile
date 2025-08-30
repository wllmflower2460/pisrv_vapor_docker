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

# Runtime stage - minimal Ubuntu with Python for AI inference
FROM ubuntu:22.04

# Install runtime dependencies including Python
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libssl3 \
    libatomic1 \
    ca-certificates \
    curl \
    wget \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /run

# Copy the built binary
COPY --from=build /app/.build/release/EdgeInfer /run/EdgeInfer

# Copy TCN-VAE models and inference service
COPY TCN-VAE_models/ /run/EdgeInfer/TCN-VAE_models/

# Set up Python virtual environment for inference
RUN cd /run/EdgeInfer/TCN-VAE_models && \
    python3 -m venv tcn_env && \
    tcn_env/bin/pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && \
    tcn_env/bin/pip install --no-cache-dir scikit-learn numpy && \
    chmod +x inference_service.py

# Create hailo mount point (ready for future integration)
RUN mkdir -p /opt/hailo
RUN mkdir -p /opt/hailo

# Expose port
EXPOSE 8080

# Health check with status-only verification (ChatGPT fix)
HEALTHCHECK --interval=30s --timeout=8s --retries=3 --start-period=90s \
  CMD curl -fsS -m 6 -o /dev/null http://localhost:8080/healthz || exit 1

# Run the app
CMD ["/run/EdgeInfer", "serve", "--hostname", "0.0.0.0", "--port", "8080"]
