# Docker Compose ContainerConfig Error

## Problem

When running `sudo docker-compose up --build`, you encounter:

```
KeyError: 'ContainerConfig'
ERROR: for postgres  'ContainerConfig'
```

## Root Cause

This is a compatibility issue between docker-compose v1.29.2 and newer Docker image formats. The older docker-compose version expects image metadata in a format that has changed in newer Docker versions.

## Solutions

### Solution 1: Clean Up and Retry (Quick Fix)

```bash
# Stop and remove all containers and volumes
sudo docker-compose down -v

# Clean up Docker system
sudo docker system prune -f

# Rebuild and start
sudo docker-compose up --build
```

### Solution 2: Use Docker Compose v2 (Recommended)

Docker Compose v2 is the modern version and doesn't have this issue:

```bash
# Check if Docker Compose v2 is available
sudo docker compose version

# If available, use it:
sudo docker compose down -v
sudo docker compose up --build
```

**Note**: Docker Compose v2 uses `docker compose` (with a space) instead of `docker-compose` (with a hyphen).

### Solution 3: Install Docker Compose v2

If Docker Compose v2 isn't installed:

```bash
# For Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker-compose-plugin

# Verify installation
sudo docker compose version

# Use it
sudo docker compose up --build
```

### Solution 4: Upgrade docker-compose v1

```bash
# Uninstall old version
sudo apt-get remove docker-compose

# Install latest from GitHub
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify
docker-compose --version
```

## Prevention

Going forward, prefer using Docker Compose v2 (`docker compose`) as v1 is deprecated:

```bash
# Instead of:
sudo docker-compose up

# Use:
sudo docker compose up
```

## Related Issues

- [Docker Compose Issue #8449](https://github.com/docker/compose/issues/8449)
- [Docker Compose Issue #8544](https://github.com/docker/compose/issues/8544)

## See Also

- [Docker Deployment Guide](../deployment/docker.md)
- [Main Troubleshooting Guide](../troubleshooting.md)
