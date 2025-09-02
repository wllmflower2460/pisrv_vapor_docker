# Pi Fresh Pull Instructions
**Date**: 2025-09-01  
**Repository**: pisrv_vapor_docker  
**Latest Push**: All branches synchronized

## 📋 Complete Fresh Pull Instructions for Pi

### 1. Navigate to Repository
```bash
cd ~/pisrv_vapor_docker
# Or wherever you cloned the repository on the Pi
```

### 2. Clean Any Local Changes (CAUTION: This removes uncommitted work)
```bash
# Check current status
git status

# If you have uncommitted changes you want to keep, stash them:
git stash push -m "Pi local changes before fresh pull"

# Clean any untracked files and reset
git clean -fd
git reset --hard HEAD
```

### 3. Fetch All Remote Branches and Tags
```bash
# Fetch everything from remote
git fetch origin --all --tags --prune

# Show what branches are available
git branch -a
```

### 4. Switch to Main Branch (Recommended Starting Point)
```bash
# Switch to main and pull latest
git checkout main
git pull origin main

# Verify you're on latest main
git log --oneline -3
# Should show: 1c14f3e docs: add submodule setup instructions to README
```

### 5. Alternative: Switch to Latest Development Branch
```bash
# If you want the latest development work with submodule fixes:
git checkout chore/scope-separate-hailo
git pull origin chore/scope-separate-hailo

# Verify you're on latest development
git log --oneline -3
# Should show: ed70732 fix: ensure submodules are properly synchronized and initialized
```

### 6. Initialize/Update Submodules (IMPORTANT!)
```bash
# Initialize and update all submodules
git submodule update --init --recursive

# Verify submodules are properly loaded
ls -la EdgeInfer/TCN-VAE_models/
ls -la DataDogsServer/h8-examples/
```

### 7. Verify Repository State
```bash
# Check git status is clean
git status

# Show current branch and commit
git branch
git log --oneline -1

# Verify all expected files are present
ls -la
```

## 🔧 Expected Repository State After Fresh Pull

### Main Branch (Stable)
- **Commit**: `1c14f3e - docs: add submodule setup instructions to README`
- **Features**: Stable Docker setup, basic Vapor API, CI pipeline

### Development Branch (Latest Features)
- **Branch**: `chore/scope-separate-hailo`
- **Commit**: `ed70732 - fix: ensure submodules are properly synchronized and initialized`
- **Features**: Enhanced submodule setup, EdgeInfer integration fixes

### Available Branches on Remote
- `main` - Stable release branch
- `chore/scope-separate-hailo` - Latest development with submodule fixes
- `ci/add-6.1-canary` - Swift 6.1 canary CI improvements
- `ci/swift-matrix` - CI matrix configuration
- `docs/sweep-submodules-and-pr-template` - Documentation improvements
- `fix/swift6-test-discovery` - Swift 6 test discovery fixes

## 🚀 Quick Start After Pull

### Build and Run (Docker)
```bash
# Build the containers
make build

# Run health check
make health

# Start the full stack
make compose-up

# Check logs
make compose-logs
```

### Build and Run (Direct Swift)
```bash
cd EdgeInfer
swift build
swift run
```

## 🐛 Troubleshooting

### If Submodules Fail to Initialize
```bash
# Remove and re-add submodules
git submodule deinit --all
git submodule update --init --recursive --force
```

### If Repository State is Inconsistent
```bash
# Nuclear option: delete and re-clone
cd ~
rm -rf pisrv_vapor_docker
git clone https://github.com/wllmflower2460/pisrv_vapor_docker.git
cd pisrv_vapor_docker
git submodule update --init --recursive
```

### If Docker Issues
```bash
# Clean Docker state
make compose-down
docker system prune -f
make build
```

## ✅ Verification Commands

Run these to verify everything is working:

```bash
# 1. Git status should be clean
git status

# 2. Submodules should be initialized
git submodule status

# 3. Health check should pass
curl -sSf http://localhost:8080/healthz || echo "Start containers first with 'make compose-up'"

# 4. Main directories should exist
ls -la EdgeInfer/ DataDogsServer/

# 5. Key files should be present
ls -la Makefile Package.swift docker-compose.yml
```

## 📝 What Changed in Latest Push

- **Submodule Configuration**: Fixed EdgeInfer/TCN-VAE_models setup
- **CI Improvements**: Swift 6.1 support, better test discovery
- **Documentation**: Enhanced README and setup instructions
- **Build System**: Improved Makefile and Docker configuration

---

**Repository URL**: https://github.com/wllmflower2460/pisrv_vapor_docker  
**All branches pushed**: ✅ Complete  
**Submodules updated**: ✅ Ready for initialization