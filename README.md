# Docker Stack Collection

A curated collection of Docker Compose stacks for self-hosted applications and services, organized by category for easy deployment and management.

## 📁 Categories

### 🤖 AI Services (`ai-services/`)
- **LiteLLM** - Proxy server for LLM APIs
- **N8N** - Workflow automation platform
- **Ollama** - Local LLM inference server
- **Open WebUI** - Web interface for AI models with TTS support

### ⛓️ Blockchain Nodes (`blockchain-nodes/`)
- **Bitcoin Core Stack** - Bitcoin node with Lightning Network (LND) support
- **Tor Integration** - Privacy-enhanced blockchain connectivity

### 🛠️ Development Tools (`development-tools/`)
- **BaGetter** - NuGet server for .NET package management

### 📺 Media Streaming (`media-streaming/`)
- **Sunshine** - Game streaming server

### 📊 Monitoring (`monitoring/`)
- **Elasticsearch** - Search and analytics engine for logs and metrics
- **Kibana** - Data visualization and exploration for Elasticsearch

### 🔒 Network Privacy (`network-privacy/`)
- **DNSMasq** - DNS server and DHCP
- **Network Client** - VPN clients (WireGuard, Tor, Proxy)
- **Nginx Proxy Manager** - Reverse proxy with SSL
- **Pi-hole** - Network-wide ad blocking
- **VPN Server** - L2TP/IPSec and OpenVPN servers

### 🖥️ Remote Access (`remote-access/`)
- **Webtop Desktop** - Browser-based desktop environments (Arch Linux)

### 🏠 Self-Hosted Privacy (`self-hosted-privacy/`)
- **HLedger Web** - Personal finance management
- **Invidious** - Privacy-focused YouTube frontend
- **SyncStorage** - Firefox Sync server

### 🔑 Identity Management (`identity-management/`)
- **Keycloak** - Identity and access management (IAM/SSO) solution

### 🔐 SSL Automation (`ssl-automation/`)
- **Cert-Manager** - Automatic SSL/TLS certificate management for Kubernetes

## 🚀 Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/docker-stack-collection.git
   cd docker-stack-collection
   ```

2. **Navigate to desired stack:**
   ```bash
   cd stacks/category-name/service-name
   ```

3. **Configure environment (if needed):**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

4. **Deploy the stack:**
   ```bash
   docker-compose up -d
   ```

## 📋 Requirements

- Docker Engine 20.10+
- Docker Compose 2.0+
- Sufficient system resources for chosen services

## 🔧 Configuration

Each stack includes:
- `docker-compose.yml` - Main service configuration
- `.env.example` - Environment variables template
- `README.md` - Service-specific documentation
- Additional configuration files as needed

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add your stack following the existing structure
4. Include proper documentation
5. Submit a pull request

## 📝 License

This project is dual-licensed under your choice of:

- **Apache License 2.0** ([LICENSE-APACHE](LICENSE-APACHE))
- **MIT License** ([LICENSE-MIT](LICENSE-MIT))

You may use this project under the terms of either license. Individual services may have their own licenses.

## ⚠️ Disclaimer

These stacks are provided as-is for educational and self-hosting purposes. Always review configurations and security settings before deploying in production environments.
