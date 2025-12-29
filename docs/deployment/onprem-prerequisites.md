# PromptForge On-Premises Deployment Prerequisites

This document outlines all prerequisites for deploying PromptForge in an on-premises environment.

**Last Updated:** 2025-01-15
**Version:** 1.0

---

## Table of Contents

- [Hardware Requirements](#hardware-requirements)
- [Software Requirements](#software-requirements)
- [Network Requirements](#network-requirements)
- [Security Requirements](#security-requirements)
- [External Services](#external-services)
- [Skills & Expertise](#skills--expertise)

---

## Hardware Requirements

### Minimum Requirements (Development/Testing)

| Component | Specification |
|-----------|--------------|
| **CPU** | 2 cores (x86_64) |
| **RAM** | 4 GB |
| **Storage** | 20 GB SSD |
| **Network** | 100 Mbps |

**Note:** Minimum requirements are suitable for development and testing only. Not recommended for production.

### Recommended Requirements (Small Production)

**For up to 100 concurrent users:**

| Component | Specification |
|-----------|--------------|
| **CPU** | 4 cores (x86_64), 2.4 GHz+ |
| **RAM** | 8 GB |
| **Storage** | 100 GB SSD |
| **Network** | 1 Gbps |
| **IOPS** | 3000+ (SSD) |

### Production Requirements (Medium Scale)

**For up to 500 concurrent users:**

| Component | Specification |
|-----------|--------------|
| **CPU** | 8 cores (x86_64), 2.8 GHz+ |
| **RAM** | 16 GB |
| **Storage** | 250 GB SSD |
| **Network** | 1 Gbps |
| **IOPS** | 5000+ (NVMe SSD) |

### Enterprise Requirements (Large Scale)

**For up to 1000+ concurrent users:**

| Component | Specification |
|-----------|--------------|
| **CPU** | 16 cores (x86_64), 3.0 GHz+ |
| **RAM** | 32 GB |
| **Storage** | 500 GB NVMe SSD |
| **Network** | 10 Gbps |
| **IOPS** | 10000+ (NVMe SSD) |

### High Availability Configuration

For High Availability deployment, you need **3 or more servers**:

**Load Balancer Node:**
- 2 cores, 4 GB RAM
- High network throughput

**Application Nodes (3+):**
- Same as single-server production requirements
- Distributed across availability zones (recommended)

**Database Nodes (3):**
- Primary + 2 replicas
- 8 cores, 16 GB RAM minimum
- Fast storage (NVMe SSD)

**Total HA Setup:**
- Minimum 7 servers (1 LB + 3 App + 3 DB)
- 56 cores, 112 GB RAM (aggregate)
- 1.5 TB storage (aggregate)

### Storage Breakdown

**Application Storage Requirements:**

| Component | Space Required | Growth Rate |
|-----------|---------------|-------------|
| **Base Application** | 5 GB | Minimal |
| **Docker Images** | 10 GB | 1-2 GB/month |
| **PostgreSQL Data** | 10 GB initial | 100 MB - 1 GB/month |
| **Redis Data** | 500 MB | Minimal |
| **Logs** | 5 GB | 500 MB/week |
| **Uploads/Media** | Variable | Depends on usage |
| **Backups** | 50 GB+ | 1-5 GB/day |
| **Total** | **80-100 GB** | **2-10 GB/month** |

**Recommended Storage Configuration:**
- OS: 50 GB (separate partition)
- Application: 100 GB (separate partition)
- Backups: 500 GB (separate partition or NAS)

---

## Software Requirements

### Operating System

**Supported Operating Systems:**

✅ **Recommended:**
- Ubuntu 22.04 LTS (Jammy Jellyfish)
- Ubuntu 20.04 LTS (Focal Fossa)
- Debian 11 (Bullseye)
- Debian 12 (Bookworm)

✅ **Supported:**
- CentOS 8 Stream
- Rocky Linux 8+
- AlmaLinux 8+
- Red Hat Enterprise Linux 8+

❌ **Not Supported:**
- Windows Server
- macOS
- Ubuntu < 20.04
- CentOS 7 (EOL)

**OS Requirements:**
- 64-bit architecture (x86_64 or ARM64)
- Kernel version 4.0+
- systemd init system

### Docker & Container Runtime

**Docker:**
- Docker Engine 20.10+ (recommended: 24.0+)
- Docker Compose 2.0+ (recommended: 2.20+)

**Installation Methods:**
- Docker CE (Community Edition) - Recommended
- Docker from official repositories
- **Not:** Docker from OS default repositories (often outdated)

**Docker Configuration Requirements:**
- Storage Driver: overlay2
- Log Driver: json-file or syslog
- Cgroup Driver: systemd (for systemd-based OS)

### Python

- Python 3.9+ (required)
- Python 3.10+ (recommended)
- pip 21.0+

**Python Packages:**
- Installed automatically during setup
- Listed in `backend/requirements.txt`

### Node.js

- Node.js 16.x LTS or 18.x LTS
- npm 8.0+
- yarn 1.22+ (optional)

### PostgreSQL

**Client Tools:**
- PostgreSQL client 14+ (for management)
- psql command-line tool

**Server (in Docker):**
- PostgreSQL 14 or 15
- Managed via Docker Compose

### System Utilities

**Required:**
- curl
- wget
- git
- tar, gzip
- openssl
- gpg
- rsync

**Recommended:**
- htop
- netstat/ss
- tcpdump
- vim or nano
- tmux or screen

### SSL/TLS

**For Production:**
- certbot (for Let's Encrypt)
- OpenSSL 1.1.1+

**For Development:**
- Self-signed certificates (generated during setup)

---

## Network Requirements

### Ports

**Required Inbound Ports:**

| Port | Protocol | Service | Access Level |
|------|----------|---------|--------------|
| **80** | TCP | HTTP | Public |
| **443** | TCP | HTTPS | Public |
| **22** | TCP | SSH | Admin only |

**Optional Ports (if not using reverse proxy):**

| Port | Protocol | Service | Access Level |
|------|----------|---------|--------------|
| 3000 | TCP | Frontend (dev) | Internal/Public |
| 8000 | TCP | Backend API (dev) | Internal/Public |

**Internal Ports (Docker network):**

| Port | Protocol | Service | Access Level |
|------|----------|---------|--------------|
| 5432 | TCP | PostgreSQL | Internal only |
| 6379 | TCP | Redis | Internal only |
| 3100 | TCP | Loki (monitoring) | Internal only |
| 9090 | TCP | Prometheus | Internal only |
| 3001 | TCP | Grafana | Internal only |

**High Availability Ports:**

| Port | Protocol | Service | Purpose |
|------|----------|---------|---------|
| 26379 | TCP | Redis Sentinel | HA coordination |
| 2377 | TCP | Docker Swarm | Cluster management |
| 7946 | TCP/UDP | Docker Swarm | Node communication |
| 4789 | UDP | Docker Swarm | Overlay network |

### Firewall Configuration

**Minimum Firewall Rules:**

```bash
# Allow SSH (from specific IPs recommended)
ufw allow 22/tcp

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Enable firewall
ufw enable
```

**For High Availability:**

```bash
# Between cluster nodes (replace IP ranges)
ufw allow from 10.0.0.0/24 to any port 2377 proto tcp
ufw allow from 10.0.0.0/24 to any port 7946
ufw allow from 10.0.0.0/24 to any port 4789 proto udp
ufw allow from 10.0.0.0/24 to any port 5432 proto tcp
ufw allow from 10.0.0.0/24 to any port 6379 proto tcp
ufw allow from 10.0.0.0/24 to any port 26379 proto tcp
```

### Bandwidth Requirements

**Per User:**
- Average: 50-100 Kbps
- Peak: 500 Kbps - 1 Mbps

**Recommended Bandwidth:**

| Users | Minimum | Recommended |
|-------|---------|-------------|
| 10 | 5 Mbps | 10 Mbps |
| 50 | 25 Mbps | 50 Mbps |
| 100 | 50 Mbps | 100 Mbps |
| 500 | 250 Mbps | 500 Mbps |
| 1000+ | 500 Mbps | 1 Gbps+ |

**Bandwidth Usage:**
- User interface: 10-50 KB per page
- API requests: 1-10 KB per request
- Uploads: Variable (depends on file size limits)
- Media: Variable (if enabled)

### DNS Requirements

**Required:**
- Resolvable domain name (production)
- DNS A record pointing to server IP
- Optional: CNAME for www subdomain

**For SSL/TLS (Let's Encrypt):**
- Public DNS record
- DNS propagation before certificate request
- CAA record (optional but recommended)

**Example DNS Configuration:**

```
promptforge.example.com.     A      203.0.113.10
www.promptforge.example.com. CNAME  promptforge.example.com.
```

### Network Topology

**Single Server:**
```
Internet → Firewall → Server → Application
```

**High Availability:**
```
Internet → Load Balancer → [Backend 1, Backend 2, Backend 3]
                         ↓
                    Database Cluster (Primary + Replicas)
                         ↓
                    Redis Cluster (Master + Slaves + Sentinels)
```

### Latency Requirements

**Internal Network:**
- Database latency: < 1ms
- Redis latency: < 1ms
- Container-to-container: < 1ms

**External:**
- User to server: < 100ms (recommended)
- API response time: < 200ms (p95)
- Page load time: < 2 seconds

---

## Security Requirements

### Access Control

**Administrative Access:**
- SSH key-based authentication (required)
- Disable password authentication
- Specific IP whitelist (recommended)
- sudo access for deployment user

**Application Access:**
- HTTPS required for production
- Strong password policy
- Session management
- CORS configuration

### Firewall

**Requirements:**
- Host-based firewall (ufw, firewalld, iptables)
- Default deny incoming
- Allow only required ports
- Rate limiting on public ports

**Recommended Tools:**
- UFW (Ubuntu/Debian)
- firewalld (RHEL/CentOS)
- fail2ban for intrusion prevention

### SSL/TLS Certificates

**Production Requirements:**
- Valid SSL certificate from trusted CA
- Let's Encrypt (free, automated)
- Commercial certificate
- Minimum TLS 1.2
- Strong cipher suites

**Development:**
- Self-signed certificates acceptable

### System Hardening

**Required:**
- Regular security updates
- Minimal installed packages
- Non-root application user
- SELinux/AppArmor (if available)
- Audit logging

**Recommended:**
- fail2ban configured
- Automatic security updates
- Intrusion detection (AIDE, OSSEC)
- Log forwarding to SIEM
- File integrity monitoring

### Secrets Management

**Requirements:**
- Encrypted .env files (chmod 600)
- Secure credential storage
- No secrets in version control
- Regular password rotation

**Options:**
- HashiCorp Vault
- AWS Secrets Manager
- Docker Secrets
- Encrypted files with GPG

### Backup Security

**Requirements:**
- Encrypted backups (GPG)
- Secure backup storage
- Access control on backups
- Off-site backup copies

### Compliance

**Consider if applicable:**
- GDPR (data protection)
- HIPAA (healthcare)
- SOC 2 (security controls)
- PCI DSS (payment data)

**Security Logging:**
- Authentication attempts
- API access logs
- Database queries (if sensitive)
- File access logs
- System changes

---

## External Services

### Required

**None** - PromptForge can run fully on-premises without external dependencies.

### Optional

**Gemini API** (if using AI features):
- Google Gemini API key
- Internet access to Gemini API endpoints
- API rate limits consideration

**Email Service** (SMTP):
- SMTP server (internal or external)
- Valid SMTP credentials
- Port 587 (TLS) or 465 (SSL) access

**Backup Storage** (off-site):
- S3-compatible storage (AWS, MinIO, etc.)
- Or SSH/rsync to remote server
- Sufficient storage capacity

**Monitoring & Alerting**:
- Slack webhook (optional)
- PagerDuty integration (optional)
- Email for alerts (recommended)

### API Rate Limits

**Gemini API:**
- Free tier: 60 requests/minute
- Consider rate limiting in application

---

## Skills & Expertise

### Required Skills

**System Administration:**
- Linux system administration
- Command-line proficiency
- File permissions and ownership
- Service management (systemd)

**Networking:**
- DNS configuration
- Firewall management
- Port forwarding/NAT
- SSL certificate management

**Docker:**
- Docker basics
- Docker Compose
- Container management
- Volume management

**Database:**
- Basic PostgreSQL knowledge
- Backup and restore
- Basic SQL

### Recommended Skills

**DevOps:**
- Git version control
- CI/CD concepts
- Infrastructure as Code

**Security:**
- SSL/TLS concepts
- Firewall configuration
- Security best practices

**Monitoring:**
- Log analysis
- Performance monitoring
- Troubleshooting

**Scripting:**
- Bash scripting
- Basic Python (for customization)

### Team Composition

**Minimum Team:**
- 1 System Administrator (Linux + Docker)

**Recommended Team:**
- 1 System Administrator
- 1 DevOps Engineer
- 1 DBA (for large deployments)

**Enterprise Team:**
- 2+ System Administrators (24/7 coverage)
- 1+ DevOps Engineers
- 1 Database Administrator
- 1 Security Engineer
- 1 Network Engineer

---

## Validation Checklist

Before proceeding with installation, verify all prerequisites:

### Hardware

- [ ] CPU meets minimum requirements
- [ ] RAM meets minimum requirements
- [ ] Storage meets minimum requirements with room for growth
- [ ] Network connectivity is adequate
- [ ] Backup storage is available

### Software

- [ ] Operating system is supported version
- [ ] OS is fully updated
- [ ] Docker can be installed (or is installed)
- [ ] Docker Compose can be installed (or is installed)
- [ ] Required system utilities are available

### Network

- [ ] Domain name is configured (production)
- [ ] DNS is resolving correctly
- [ ] Required ports are available
- [ ] Firewall rules are planned
- [ ] Bandwidth is adequate

### Security

- [ ] SSH key authentication is configured
- [ ] Firewall is available and configurable
- [ ] SSL certificate plan is in place
- [ ] Backup security is planned
- [ ] Security hardening plan is ready

### Access & Permissions

- [ ] Administrative access to server
- [ ] sudo privileges are available
- [ ] DNS management access (if needed)
- [ ] Firewall management access
- [ ] Backup storage access (if off-site)

### Team & Knowledge

- [ ] Required skills are available in team
- [ ] Documentation has been reviewed
- [ ] Support plan is in place
- [ ] Maintenance windows are scheduled

---

## Next Steps

Once all prerequisites are met:

1. **Review** the [Installation Guide](onprem-installation.md)
2. **Prepare** the server environment
3. **Execute** the installation
4. **Configure** the application
5. **Verify** the deployment

---

## Support & Resources

**Documentation:**
- [Installation Guide](onprem-installation.md)
- [Configuration Guide](onprem-configuration.md)
- [Maintenance Guide](onprem-maintenance.md)
- [Disaster Recovery](onprem-disaster-recovery.md)

**Getting Help:**
- Review documentation thoroughly
- Check troubleshooting guides
- Review GitHub issues
- Contact support team

---

**Document Version:** 1.0
**Last Updated:** 2025-01-15
**Review Frequency:** Quarterly
