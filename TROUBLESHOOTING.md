# Hailo-8 Video Processing API - Troubleshooting Guide

## System Overview

This system provides a Vapor-based Swift API for uploading videos and processing them through a Hailo-8 AI accelerator. The architecture consists of:

- **Vapor API** (Swift): Handles video uploads, runs in Docker on port 8082
- **Session Worker** (Python): Background service that processes uploaded sessions via Hailo CLI
- **HailoRT Service**: Low-level service managing the Hailo-8 device
- **File System**: Shared session directory between API and worker

## Quick Health Checks

### 1. API Health Check
```bash
curl http://localhost:8082/healthz
# Expected: {"ok":true}
```

### 2. Service Status Check
```bash
sudo systemctl status docker
sudo systemctl status hailort  
sudo systemctl status data-dogs-worker
sudo systemctl status docker-vapor
```

### 3. Container Status
```bash
docker ps | grep vapor
# Expected: vapor container on port 8082:8080, status "healthy"
```

### 4. Hailo Device Test
```bash
sudo -u pi hailortcli benchmark -t 1 /opt/hailo/models/sample.hef
# Expected: FPS and latency metrics without errors
```

## Common Issues & Solutions

### Issue 1: "HAILO_OUT_OF_PHYSICAL_DEVICES" Error

**Symptoms:**
- 202 processing responses that eventually return error status
- Session worker logs show device exhaustion

**Diagnosis:**
```bash
# Check for device lock
ps aux | grep hailo
sudo lsof /dev/hailo0 2>/dev/null || echo "No processes using /dev/hailo0"
```

**Solution:**
```bash
# Restart HailoRT service to release device
sudo systemctl restart hailort

# Verify device is accessible
sudo -u pi hailortcli benchmark -t 1 /opt/hailo/models/sample.hef
```

### Issue 2: Session Processing Stuck at 202

**Symptoms:**
- API returns {"status": "processing"} indefinitely
- No results.json file appears in session directory

**Diagnosis:**
```bash
# Check session worker logs
sudo journalctl -u data-dogs-worker -f

# Check pending sessions
ls -la /home/pi/appdata/sessions/
find /home/pi/appdata/sessions -name "video.mp4" -not -path "*/backups/*" | wc -l
find /home/pi/appdata/sessions -name "results.json" -not -path "*/backups/*" | wc -l
```

**Solution:**
```bash
# Restart session worker
sudo systemctl restart data-dogs-worker

# Check for permission issues
ls -la /home/pi/appdata/sessions/[SESSION_ID]/
```

### Issue 3: Permission Denied Errors

**Symptoms:**
- Session worker can't read/write files
- Docker container can't access session directory

**Diagnosis:**
```bash
# Check directory ownership
ls -la /home/pi/appdata/sessions/

# Check Docker container user
docker exec vapor id
```

**Solution:**
```bash
# Fix ownership (if needed)
sudo chown -R pi:pi /home/pi/appdata/sessions/
sudo chmod -R 755 /home/pi/appdata/sessions/

# Ensure Docker runs as pi user (should be in docker-compose.yml)
# user: "1000:1000"
```

### Issue 4: API Not Accessible on Port 8082

**Symptoms:**
- Connection refused to localhost:8082
- Container not running

**Diagnosis:**
```bash
# Check if container is running
docker ps | grep vapor

# Check port binding
netstat -tlnp | grep 8082
```

**Solution:**
```bash
# Restart the service
sudo systemctl restart docker-vapor

# Or manually restart
cd /home/pi/vapor-docker
docker compose down && docker compose up -d
```

### Issue 5: Session Backlog Building Up

**Symptoms:**
- Many sessions with video.mp4 but no results.json
- Processing getting slower

**Diagnosis:**
```bash
# Count pending sessions
find /home/pi/appdata/sessions -name "video.mp4" -not -path "*/backups/*" | wc -l
find /home/pi/appdata/sessions -name "results.json" -not -path "*/backups/*" | wc -l
```

**Solution:**
```bash
# Clean up old sessions (creates backup)
BACKUP_DIR="/home/pi/appdata/sessions_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Move sessions older than 1 day to backup
find /home/pi/appdata/sessions -maxdepth 1 -type d -name "*-*-*-*-*" -mtime +1 -exec mv {} "$BACKUP_DIR"/ \;

# Restart services to clear any stuck state
sudo systemctl restart hailort
sudo systemctl restart data-dogs-worker
```

## Service Configuration Files

### Key Files:
- **API Code**: `/home/pi/vapor-docker/Sources/App/`
- **Docker Config**: `/home/pi/vapor-docker/docker-compose.yml`
- **Session Worker**: `/opt/hailo/session_worker.py`
- **Worker Service**: `/etc/systemd/system/data-dogs-worker.service`
- **Docker Service**: `/etc/systemd/system/docker-vapor.service`
- **Sessions Data**: `/home/pi/appdata/sessions/`

### Environment Variables:
```bash
# In docker-compose.yml
SESSIONS_DIR: /var/app/sessions  # Inside container
LOG_LEVEL: info
# API_KEY: commented out (no authentication)
```

## API Endpoints

### Upload Session
```bash
POST http://localhost:8082/sessions
Content-Type: multipart/form-data
- video: video.mp4 file
- imu: JSON string with IMU data
- meta: JSON string with metadata
```

### Get Session Results  
```bash
GET http://localhost:8082/sessions/{SESSION_ID}/results
# Returns: processing (202) or results JSON (200) or error (200)
```

### Get Session Info
```bash
GET http://localhost:8082/sessions/{SESSION_ID}
# Returns: file sizes and availability
```

## Performance Metrics

**Expected Performance:**
- **FPS (HW-only)**: ~29.96 FPS
- **FPS (Streaming)**: ~29.96 FPS  
- **Hardware Latency**: ~30.8ms
- **Processing Time**: 3-5 seconds per session

## System Architecture Diagram

```
[iOS App] 
    ↓ POST /sessions (video + IMU)
[Vapor API:8082] 
    ↓ writes files to
[/home/pi/appdata/sessions/{UUID}/]
    ↓ monitors directory
[Session Worker Service]
    ↓ calls
[hailortcli benchmark]
    ↓ uses
[Hailo-8 Device via HailoRT Service]
    ↓ writes
[results.json]
    ↓ reads
[Vapor API] → returns to [iOS App]
```

## Emergency Recovery

### Complete System Reset:
```bash
# Stop all services
sudo systemctl stop docker-vapor
sudo systemctl stop data-dogs-worker  
sudo systemctl stop hailort
sudo systemctl stop docker

# Clean Docker state
docker system prune -f

# Start services in order
sudo systemctl start docker
sudo systemctl start hailort
sudo systemctl start data-dogs-worker
sudo systemctl start docker-vapor

# Verify everything is working
curl http://localhost:8082/healthz
```

### Service Start Order (for boot issues):
1. `docker.service`
2. `hailort.service`  
3. `docker-vapor.service` (starts Vapor API)
4. `data-dogs-worker.service` (starts session processor)

## Monitoring Commands

### Watch Session Processing:
```bash
# Monitor session worker
sudo journalctl -u data-dogs-worker -f

# Watch sessions directory
watch "ls -la /home/pi/appdata/sessions/"

# Monitor API logs
docker logs -f vapor
```

### System Resource Check:
```bash
# Check disk space
df -h /home/pi/appdata/

# Check memory usage
free -h

# Check Hailo device
ls -la /dev/hailo*
```

---
**Last Updated**: August 16, 2025
**System Version**: Vapor 4.83.0+, HailoRT, Raspberry Pi 5
