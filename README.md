<p align="center">
    <img src="https://user-images.githubusercontent.com/1342803/36623515-7293b4ec-18d3-11e8-85ab-4e2f8fb38fbd.png" width="320" alt="API Template">
    <br>
    <br>
    <a href="http://docs.vapor.codes/3.0/">
        <img src="http://img.shields.io/badge/read_the-docs-2196f3.svg" alt="Documentation">
    </a>
    <a href="https://discord.gg/vapor">
        <img src="https://img.shields.io/discord/431917998102675485.svg" alt="Team Chat">
    </a>
    <a href="LICENSE">
        <img src="http://img.shields.io/badge/license-MIT-brightgreen.svg" alt="MIT License">
    </a>
    <a href="https://circleci.com/gh/vapor/api-template">
        <img src="https://circleci.com/gh/vapor/api-template.svg?style=shield" alt="Continuous Integration">
    </a>
    <a href="https://swift.org">
        <img src="http://img.shields.io/badge/swift-5.1-brightgreen.svg" alt="Swift 5.1">
    </a>
</p>

# Data Dogs – Vapor API (Pi) + Hailo Worker (optional)

Vapor 4 API running on a Raspberry Pi. Accepts video + IMU uploads from an iOS app, stores them under a bind-mounted sessions dir, and (optionally) kicks off a Hailo-8 worker that writes `results.json` per session.

## TL;DR

```bash
# Build
docker build -t vapor-app:clean .

# Run (API key disabled for easier testing)
docker rm -f vapor-app 2>/dev/null || true
docker run -d --name vapor-app \
  --user 1000:1000 \
  -p 8082:8080 \
  -e SESSIONS_DIR=/var/app/sessions \
  -v /home/pi/appdata/sessions:/var/app/sessions \
  vapor-app:clean

# Health check (open)
curl -sSf http://localhost:8082/healthz

# List sessions (no auth required)
curl -sSf http://localhost:8082/sessions | jq

### Config
Copy `Resources/ServerConfig.example.plist` → `ServerConfig.plist` and set:
- BaseURL: http://<pi-ip>:8082
- APIKey:  (not required - leave empty)

(Optional) Use Debug tab to override at runtime via UserDefaults.

### Notes
- If BaseURL is http://, Info.plist includes ATS local-network exception.
- For stable demos, prefer Pi IP over mDNS hostnames.

Session Retention
Purpose: Automatically purge old training session folders to free space and keep the server tidy.

Path: /home/pi/appdata/sessions

Retention Window:
Session directories older than 7 days are deleted.

Automation:
Managed by clean-sessions.service (oneshot) + clean-sessions.timer (daily).
Timer runs every day at 03:30 local time.

Manual Run:
sudo systemctl start clean-sessions.service

Force a Test Deletion:
BASE=/home/pi/appdata/sessions
mkdir -p "$BASE/OLD_TEST"
sudo touch -d "8 days ago" "$BASE/OLD_TEST"
sudo systemctl start clean-sessions.service

Check Logs:
journalctl -u clean-sessions.service -n 50 --no-pager

Check Timer Status:
systemctl list-timers | grep clean-sessions

Script Location:
/usr/local/bin/clean-sessions.sh

Unit Files:
/etc/systemd/system/clean-sessions.service
/etc/systemd/system/clean-sessions.timer