# Field Deployment Checklist - EdgeInfer Behavioral Analysis System

**System**: Raspberry Pi 5 + Hailo-8 + GL-XE300 LTE Router  
**Application**: Professional dog training behavioral analysis  
**Version**: EdgeInfer v1.0 with Prometheus monitoring  
**Date**: August 28, 2025

---

## Pre-Deployment Hardware Checklist

### ✅ **Equipment Verification**
- [ ] **Raspberry Pi 5** with adequate cooling (fan/heatsink)
- [ ] **Hailo-8 M.2 AI Accelerator** properly seated
- [ ] **GL-XE300 LTE Router** with active SIM card
- [ ] **MicroSD Card** (64GB+, Class 10) with latest system image
- [ ] **Power supplies**: Pi (27W USB-C) + Router (12V adapter)
- [ ] **Ethernet cable** (Pi to Router connection)
- [ ] **iPhone/iPad** with DataDogs app installed

### ✅ **Network Configuration**
- [ ] **SIM Card** activated with adequate data plan (5GB+ recommended)
- [ ] **Router Admin Access**: Default 192.168.8.1 (admin/password)
- [ ] **Pi Static IP**: Reserved at 192.168.8.241
- [ ] **Port Forwarding**: Configured if external access needed

---

## Software Deployment Steps

### 1. **System Preparation**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker and dependencies
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker pi

# Install Git
sudo apt install -y git
```

### 2. **EdgeInfer Deployment**
```bash
# Clone repository
cd /home/pi
git clone https://github.com/wllmflower2460/pisrv_vapor_docker.git
cd pisrv_vapor_docker

# Build and deploy EdgeInfer
docker-compose build edge-infer
docker-compose up -d edge-infer

# Wait 90 seconds for Swift warm-up, then verify
sleep 90
docker ps | grep edge-infer  # Should show "healthy"
curl http://localhost:8080/healthz  # Should return JSON
```

### 3. **Monitoring Stack (Optional)**
```bash
# Deploy full monitoring stack
docker-compose -f docker-compose-monitoring.yml up -d

# Verify services
docker ps  # Should show: prometheus, grafana, node-exporter, cadvisor
curl http://localhost:9090/targets  # Prometheus targets should be UP
```

---

## Field Testing Checklist

### ✅ **Network Connectivity**
- [ ] **Router Online**: LTE signal strength >2 bars
- [ ] **Pi Network**: Ping 192.168.8.241 successful
- [ ] **Internet Access**: Pi can reach external services
- [ ] **iOS Connection**: iPhone connects to router WiFi

### ✅ **EdgeInfer API Validation**
```bash
# Test all endpoints
curl -X POST http://192.168.8.241:8080/api/v1/analysis/start -H "Content-Type: application/json" -d '{}'
# Expected: {"sessionId":"UUID","status":"started","timestamp":...}

# Test health endpoint
curl http://192.168.8.241:8080/healthz
# Expected: {"status":"healthy","timestamp":"...","service":"EdgeInfer","version":"1.0.0"}

# Test metrics
curl http://192.168.8.241:8080/metrics | head -20
# Expected: Prometheus metrics output
```

### ✅ **iOS App Integration**
- [ ] **App Configuration**: BaseURL set to `http://192.168.8.241:8080`
- [ ] **Session Creation**: App can start analysis sessions
- [ ] **Real-time Streaming**: IMU data uploads successfully
- [ ] **Motif Detection**: Receives K=12 behavioral motifs
- [ ] **Synchrony Analysis**: Handler-dog synchrony metrics returned

---

## Performance Monitoring

### ✅ **System Health Indicators**
- [ ] **Container Status**: `docker ps` shows all services healthy
- [ ] **CPU Usage**: <60% under normal load (`htop`)
- [ ] **Memory Usage**: <75% of available RAM
- [ ] **Storage**: <80% of SD card capacity (`df -h`)
- [ ] **Temperature**: CPU <70°C (`vcgencmd measure_temp`)

### ✅ **Network Performance**
- [ ] **Latency**: <100ms response time for API calls
- [ ] **Throughput**: Handles real-time IMU streaming (100Hz)
- [ ] **Stability**: No session drops during 30-minute training session

### ✅ **Monitoring Dashboards** (if deployed)
- [ ] **Grafana**: Accessible at http://192.168.8.241:3000 (admin/change_me)
- [ ] **API Metrics**: Request rates, response times, error rates
- [ ] **System Metrics**: CPU, memory, disk, network usage
- [ ] **Container Metrics**: Docker container performance

---

## Troubleshooting Quick Reference

### 🔧 **Common Issues**

**EdgeInfer Container Unhealthy**
```bash
# Check logs
docker logs edge-infer --tail 50

# Restart if needed
docker-compose restart edge-infer

# Wait for 90s startup period
```

**iOS App Can't Connect**
```bash
# Verify Pi IP
ip addr show | grep 192.168.8.241

# Check router configuration
ping 192.168.8.1

# Test from Pi
curl http://localhost:8080/healthz
```

**Performance Issues**
```bash
# Check system resources
htop
vcgencmd measure_temp
df -h
```

### 🚨 **Emergency Procedures**

**Complete System Reset**
```bash
# Stop all services
docker-compose down
docker-compose -f docker-compose-monitoring.yml down

# Clean Docker state
docker system prune -f

# Restart services
docker-compose up -d
```

**Network Recovery**
```bash
# Reset network configuration
sudo systemctl restart networking
sudo dhcpcd restart

# Verify connectivity
ping 8.8.8.8
```

---

## Deployment Sign-off

### ✅ **Technical Validation**
- [ ] All Docker containers running and healthy
- [ ] API endpoints responding within 50ms
- [ ] iOS app successfully connects and functions
- [ ] System performance within acceptable limits
- [ ] Monitoring (if deployed) shows green across all metrics

### ✅ **Field Validation** 
- [ ] LTE connectivity stable in target location
- [ ] Battery life adequate for training session duration
- [ ] Equipment secure and weather-protected
- [ ] Trainer familiar with basic operation procedures

### ✅ **Documentation Handoff**
- [ ] Trainer provided with operation guide
- [ ] Emergency contact information provided
- [ ] Backup/recovery procedures documented
- [ ] System specifications and limitations communicated

---

**Deployment Completed By**: ________________  
**Date**: ________________  
**Location**: ________________  
**Trainer/End User**: ________________  
**Next Maintenance Due**: ________________

---

## Support Information

**Technical Support**: willflower2460@github.com  
**Repository**: https://github.com/wllmflower2460/pisrv_vapor_docker  
**Documentation**: See TROUBLESHOOTING_EdgeInfer_Deployment_v2.md  
**Monitoring**: http://192.168.8.241:3000 (if deployed)

**System Specifications**:
- EdgeInfer API: Port 8080
- Prometheus: Port 9090 (monitoring)
- Grafana: Port 3000 (monitoring)
- Expected performance: <50ms API response, K=12 motifs, real-time synchrony analysis