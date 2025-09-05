"""
Hailo Sidecar Metrics Template
This template demonstrates how to add comprehensive monitoring to the Hailo FastAPI sidecar.
"""

import time
import psutil
import asyncio
from fastapi import FastAPI, Request, Response
from fastapi.middleware.base import BaseHTTPMiddleware
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import logging

# Prometheus Metrics for Hailo Sidecar
REQUEST_COUNT = Counter(
    'hailo_http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status_code']
)

REQUEST_DURATION = Histogram(
    'hailo_http_request_duration_seconds', 
    'HTTP request duration',
    ['method', 'endpoint']
)

INFERENCE_COUNT = Counter(
    'hailo_inference_requests_total',
    'Total inference requests',
    ['model_type', 'status']
)

INFERENCE_DURATION = Histogram(
    'hailo_inference_duration_seconds',
    'Model inference duration',
    ['model_type', 'operation']
)

SAMPLE_COUNT = Counter(
    'hailo_samples_processed_total',
    'Total samples processed',
    ['input_type']
)

MODEL_OUTPUT_SIZE = Gauge(
    'hailo_model_output_dimensions',
    'Model output dimensions',
    ['output_type']
)

MEMORY_USAGE = Gauge(
    'hailo_memory_usage_bytes',
    'Memory usage in bytes',
    ['memory_type']
)

CPU_USAGE = Gauge(
    'hailo_cpu_usage_percent',
    'CPU usage percentage'
)

HAILORT_STATUS = Gauge(
    'hailo_hailort_status',
    'HailoRT SDK status (1=healthy, 0=unhealthy)',
    ['device_id']
)

HARDWARE_TEMP = Gauge(
    'hailo_hardware_temperature_celsius',
    'Hailo-8 chip temperature',
    ['chip_id']
)

HARDWARE_UTILIZATION = Gauge(
    'hailo_hardware_utilization_percent',
    'Hailo-8 chip utilization percentage',
    ['chip_id']
)

class MetricsMiddleware(BaseHTTPMiddleware):
    """FastAPI middleware to collect HTTP metrics"""
    
    async def dispatch(self, request: Request, call_next):
        start_time = time.time()
        
        # Process the request
        response = await call_next(request)
        
        # Calculate duration
        duration = time.time() - start_time
        
        # Record metrics
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.url.path,
            status_code=response.status_code
        ).inc()
        
        REQUEST_DURATION.labels(
            method=request.method,
            endpoint=request.url.path
        ).observe(duration)
        
        return response

class HailoMetricsCollector:
    """Collects Hailo-specific metrics"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        
    async def record_inference(self, model_type: str, operation: str, 
                              duration: float, success: bool, sample_count: int,
                              latent_size: int = None, motif_count: int = None):
        """Record inference operation metrics"""
        
        # Record inference request
        status = "success" if success else "failure"
        INFERENCE_COUNT.labels(model_type=model_type, status=status).inc()
        
        if success:
            # Record inference timing
            INFERENCE_DURATION.labels(model_type=model_type, operation=operation).observe(duration)
            
            # Record samples processed
            SAMPLE_COUNT.labels(input_type="imu_samples").inc(sample_count)
            
            # Record model output dimensions
            if latent_size:
                MODEL_OUTPUT_SIZE.labels(output_type="latent_vector").set(latent_size)
            if motif_count:
                MODEL_OUTPUT_SIZE.labels(output_type="motif_classes").set(motif_count)
        
        self.logger.info(f"Recorded {model_type} {operation}: {duration:.3f}s, {status}, {sample_count} samples")
    
    async def update_system_metrics(self):
        """Update system resource metrics"""
        try:
            # Memory usage
            memory = psutil.virtual_memory()
            MEMORY_USAGE.labels(memory_type="rss").set(memory.used)
            MEMORY_USAGE.labels(memory_type="available").set(memory.available)
            
            # CPU usage
            cpu_percent = psutil.cpu_percent(interval=1)
            CPU_USAGE.set(cpu_percent)
            
        except Exception as e:
            self.logger.error(f"Failed to update system metrics: {e}")
    
    async def update_hailort_metrics(self):
        """Update HailoRT SDK and hardware metrics"""
        try:
            # This would integrate with actual HailoRT SDK calls
            # For template purposes, using mock values
            
            # Mock HailoRT device status
            HAILORT_STATUS.labels(device_id="0").set(1)  # 1 = healthy
            
            # Mock hardware temperature (would come from HailoRT)
            HARDWARE_TEMP.labels(chip_id="hailo8_0").set(65.5)  # Celsius
            
            # Mock hardware utilization (would come from HailoRT)
            HARDWARE_UTILIZATION.labels(chip_id="hailo8_0").set(75.2)  # Percentage
            
        except Exception as e:
            self.logger.error(f"Failed to update HailoRT metrics: {e}")
    
    async def start_background_collection(self):
        """Start background metrics collection task"""
        while True:
            try:
                await self.update_system_metrics()
                await self.update_hailort_metrics()
                await asyncio.sleep(10)  # Update every 10 seconds
            except Exception as e:
                self.logger.error(f"Background metrics collection failed: {e}")
                await asyncio.sleep(30)  # Retry after 30 seconds on error

# FastAPI integration example
app = FastAPI(title="Hailo TCN-VAE Inference Sidecar")
app.add_middleware(MetricsMiddleware)

metrics_collector = HailoMetricsCollector()

@app.on_event("startup")
async def startup_event():
    """Start background metrics collection on startup"""
    asyncio.create_task(metrics_collector.start_background_collection())

@app.get("/metrics")
async def get_metrics():
    """Prometheus metrics endpoint"""
    return Response(
        generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )

@app.get("/healthz")
async def health_check():
    """Health check endpoint with metrics"""
    start_time = time.time()
    
    try:
        # Perform health checks (HailoRT, model loading, etc.)
        # Mock health check for template
        health_status = "OK"
        
        # Record health check metrics
        duration = time.time() - start_time
        await metrics_collector.record_inference(
            model_type="health_check",
            operation="status_check", 
            duration=duration,
            success=True,
            sample_count=0
        )
        
        return {"status": health_status}
        
    except Exception as e:
        duration = time.time() - start_time
        await metrics_collector.record_inference(
            model_type="health_check",
            operation="status_check",
            duration=duration, 
            success=False,
            sample_count=0
        )
        raise

@app.post("/infer")
async def infer_tcn_vae(request: dict):
    """TCN-VAE inference endpoint with comprehensive metrics"""
    start_time = time.time()
    
    try:
        # Extract IMU data
        imu_data = request.get("x", [])
        sample_count = len(imu_data)
        
        # Perform TCN-VAE inference (mock for template)
        # This would integrate with actual HailoRT inference
        latent_vector = [0.0] * 64  # Mock latent vector
        motif_scores = [0.5] * 12   # Mock motif scores
        
        # Calculate inference time
        inference_time = time.time() - start_time
        
        # Record successful inference metrics
        await metrics_collector.record_inference(
            model_type="tcn_vae",
            operation="inference",
            duration=inference_time,
            success=True,
            sample_count=sample_count,
            latent_size=len(latent_vector),
            motif_count=len(motif_scores)
        )
        
        return {
            "latent": latent_vector,
            "motif_scores": motif_scores
        }
        
    except Exception as e:
        # Record failed inference metrics
        inference_time = time.time() - start_time
        await metrics_collector.record_inference(
            model_type="tcn_vae",
            operation="inference",
            duration=inference_time,
            success=False,
            sample_count=len(request.get("x", []))
        )
        raise

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=9000)