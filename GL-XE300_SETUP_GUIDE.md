# GL-XE300 LTE Router + Raspberry Pi Setup Guide

**Equipment**: GL-XE300 Portable LTE Router + Raspberry Pi 5  
**Purpose**: Field deployment for EdgeInfer behavioral analysis system  
**Target Network**: 192.168.8.0/24 with Pi at 192.168.8.241  
**Documentation**: https://docs.gl-inet.com/router/en/4/interface_guide/gl-xe300/

---

## Hardware Setup

### 1. **GL-XE300 Initial Setup**
- Insert activated LTE SIM card into SIM slot
- Connect 12V power adapter
- Power on router (LED should turn blue when connected to LTE)
- Wait 2-3 minutes for LTE connection establishment

### 2. **Raspberry Pi 5 Connection**
- Connect Pi to router via Ethernet cable (Port 1 or Port 2)
- Power on Pi with 27W USB-C adapter
- Pi will receive IP via DHCP initially

---

## Router Configuration

### 1. **Access Router Admin Interface**
```
URL: http://192.168.8.1
Default User: admin
Default Password: (check router label or use 'admin')
```

### 2. **Set Router Password (First Login)**
- Create secure admin password
- Note password for future access
- Complete initial setup wizard

### 3. **Configure LTE Connection**
**Navigation**: Internet → Cellular
- **APN Settings**: Auto-detect or manual configuration
- **Network Mode**: 4G LTE (preferred) or Auto
- **Data Limit**: Set monthly limit if needed (recommend 10GB+)
- **Connection Status**: Should show "Connected" with signal strength

### 4. **WiFi Configuration** 
**Navigation**: Wireless → WiFi Settings
```
WiFi Name (SSID): DataDogs-Field-[Location]
Password: [Create secure 12+ character password]
Security: WPA2/WPA3 Mixed
Channel: Auto (or manual 1, 6, 11 for 2.4GHz)
```

### 5. **Network Settings**
**Navigation**: Network → LAN Settings
```
Router IP: 192.168.8.1 (default - keep)
Subnet Mask: 255.255.255.0
DHCP Range: 192.168.8.100 - 192.168.8.200
DNS Servers: 
  Primary: 8.8.8.8
  Secondary: 8.8.4.4
```

---

## Raspberry Pi Static IP Configuration

### 1. **Find Pi's Current IP**
From router admin interface:
**Navigation**: Clients → View connected devices
Look for device with MAC starting with: `b8:27:eb`, `dc:a6:32`, or `d8:3a:dd`

### 2. **Reserve Static IP for Pi**
**Navigation**: Network → DHCP Reservations

```
MAC Address: [Pi's MAC address from step 1]
IP Address: 192.168.8.241
Hostname: raspberrypi-edgeinfer
```

**Alternative CLI method on Pi:**
```bash
# Edit dhcpcd.conf
sudo nano /etc/dhcpcd.conf

# Add at end of file:
interface eth0
static ip_address=192.168.8.241/24
static routers=192.168.8.1
static domain_name_servers=8.8.8.8 8.8.4.4

# Restart networking
sudo systemctl restart dhcpcd
```

### 3. **Verify Network Configuration**
From Pi:
```bash
# Check IP assignment
ip addr show eth0 | grep "inet "
# Expected: inet 192.168.8.241/24

# Test router connectivity
ping -c 4 192.168.8.1

# Test internet connectivity
ping -c 4 8.8.8.8

# Test DNS resolution
nslookup google.com
```

---

## Port Forwarding (Optional - External Access)

⚠️ **Security Warning**: Only enable if external access required. Consider VPN instead.

**Navigation**: Network → Port Forwards

### EdgeInfer API Access
```
Protocol: TCP
External Port: 8080
Internal IP: 192.168.8.241
Internal Port: 8080
Description: EdgeInfer API
```

### Monitoring Access
```
Protocol: TCP  
External Port: 3000
Internal IP: 192.168.8.241
Internal Port: 3000
Description: Grafana Monitoring
```

---

## Firewall Configuration

**Navigation**: Network → Firewall

### 1. **Basic Security Settings**
```
Enable SPI Firewall: ✓
Block WAN Ping: ✓
Enable DoS Protection: ✓
```

### 2. **Allow Local Network Traffic**
```
Source: 192.168.8.0/24
Destination: 192.168.8.241
Port: 8080, 9090, 3000
Action: Allow
```

---

## Performance Optimization

### 1. **LTE Optimization**
**Navigation**: Internet → Cellular → Advanced
```
Network Mode: 4G LTE Only (if good signal)
Band Selection: Auto or lock to strongest local band
Data Roaming: Disable (unless needed)
```

### 2. **WiFi Optimization** 
**Navigation**: Wireless → Advanced Settings
```
Channel Width: 20MHz (better range) or 40MHz (better speed)
Transmit Power: High (for field use)
Beacon Interval: 100ms (default)
```

### 3. **QoS Settings**
**Navigation**: Network → QoS
```
Enable QoS: ✓
Total Bandwidth: Set to 80% of LTE plan speed
Priority Traffic:
  - EdgeInfer API (192.168.8.241:8080): High Priority
  - DNS Traffic: High Priority
```

---

## Monitoring and Diagnostics

### 1. **Router Status Monitoring**
**Dashboard**: Main interface shows:
- LTE signal strength and data usage
- Connected devices count
- CPU and memory usage
- WAN/LAN traffic statistics

### 2. **Network Diagnostics**
**Navigation**: System → Diagnostics
```
# Ping Test: Verify internet connectivity
Target: 8.8.8.8
# Expected: <100ms latency, 0% packet loss

# Traceroute: Check routing path
# Should show: Pi → Router → LTE tower → Internet

# Speed Test: Measure LTE performance
# Expected: 10+ Mbps down, 3+ Mbps up (varies by location)
```

### 3. **Log Monitoring**
**Navigation**: System → Log
Monitor for:
- LTE connection drops
- DHCP lease assignments
- Firewall blocks
- System errors

---

## Troubleshooting

### 🔧 **Common Issues**

**No LTE Connection**
```bash
# Check SIM card
# Verify APN settings with carrier
# Check signal strength (move to better location)
# Restart router: Power off 30 seconds, power on
```

**Pi Can't Get IP**
```bash
# Check Ethernet cable connection
# Verify DHCP is enabled on router
# Check DHCP reservation configuration
# Restart Pi networking: sudo systemctl restart dhcpcd
```

**Slow Internet Performance**
```bash
# Check LTE signal strength (aim for >-85 dBm)
# Verify QoS settings not too restrictive
# Test with different DNS servers
# Check data plan throttling
```

**iOS App Can't Connect**
```bash
# Verify iPhone connected to router WiFi
# Test Pi accessibility: ping 192.168.8.241
# Check EdgeInfer API: curl http://192.168.8.241:8080/healthz
# Verify firewall allows local traffic
```

---

## Factory Reset Procedure

### 1. **Router Factory Reset**
- Power on router
- Press and hold Reset button for 10+ seconds
- Wait for LED to flash, then restart
- Reconfigure from scratch using this guide

### 2. **Preserve Configuration**
**Navigation**: System → Backup & Restore
- **Backup**: Download configuration file before deployment
- **Restore**: Upload saved configuration if reset needed

---

## Field Deployment Checklist

### ✅ **Pre-Deployment**
- [ ] LTE SIM card activated and tested
- [ ] Router admin password set and documented
- [ ] Pi static IP (192.168.8.241) configured and verified
- [ ] WiFi password created and documented
- [ ] EdgeInfer API accessible at http://192.168.8.241:8080
- [ ] iOS app configured with correct BaseURL

### ✅ **Signal Testing**
- [ ] LTE signal strength adequate at deployment location
- [ ] Internet speed test successful (10+ Mbps down)
- [ ] WiFi coverage adequate for working area
- [ ] No interference from other wireless networks

### ✅ **Performance Validation**
- [ ] API response time <50ms
- [ ] No packet loss during 10-minute test
- [ ] Data usage tracking functional
- [ ] All devices maintain stable connections

---

## Network Topology

```
[Internet] 
    ↕ (LTE)
[GL-XE300 Router]
192.168.8.1
    ↕ (Ethernet)
[Raspberry Pi 5]
192.168.8.241:8080
    ↕ (WiFi)
[iPhone/iPad]
192.168.8.xxx
```

---

## Support Information

**GL-iNet Support**: https://www.gl-inet.com/support/  
**Router Manual**: https://docs.gl-inet.com/router/en/4/interface_guide/gl-xe300/  
**Firmware Updates**: Available through admin interface (System → Upgrade)  
**EdgeInfer Documentation**: See repository README.md

**Configuration Summary**:
- Router IP: 192.168.8.1
- Pi Static IP: 192.168.8.241  
- EdgeInfer API: http://192.168.8.241:8080
- WiFi SSID: DataDogs-Field-[Location]
- Admin Interface: http://192.168.8.1