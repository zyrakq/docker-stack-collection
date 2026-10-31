# Readme Gen — Templates

## Template A: Stack-root hub README

````markdown
# <emoji> <Name> Stack

<1-2 sentence description of the complete stack.>

## 🧩 Components

### <emoji> [<Component Name>](app/)

<1-2 sentence blurb.>

### 🌐 [Let's Encrypt Manager](modules/ssl-automation/letsencrypt-manager/)

Automatic SSL certificate generation and renewal using Let's Encrypt for
production deployments with internet access.

### 🔒 [Step CA Manager](modules/ssl-automation/step-ca-manager/)

Self-signed trusted certificate authority for virtual Docker networks
without internet access. Automatically manages and distributes CA
certificates within isolated environments.

## 🚀 Quick Start

Each component has its own README with detailed setup instructions. Choose
the certificate management solution that fits your deployment scenario.

<Optional: numbered example deployment flow — cd app/ && sb build →
cd build/<env>/<ext>/ → cp .env.example .env → docker compose up --build -d>

## 📋 Requirements

- Docker & Docker Compose
- Domain name (for production deployments)
- Email address (for Let's Encrypt)

## 📄 License

This project is dual-licensed under:

- [Apache License 2.0](LICENSE-APACHE)
- [MIT License](LICENSE-MIT)
````

## Template B: Component README (~100-250 lines)

````markdown
# <emoji> <Service Name>

A modular Docker Compose configuration system for <X> with <key
capabilities>.

## 🚀 Quick Start

### 1. Build Configurations

```bash
sb build
```

This will create all combinations in the `build/` directory based on
[`stackbuilder.toml`](stackbuilder.toml).

### 2. Choose Your Configuration

```bash
# For development with port forwarding
cd build/forwarding/<combo>/

# For production with Let's Encrypt SSL
cd build/letsencrypt/<combo>/

# For production with Step CA SSL
cd build/step-ca/<combo>/
```

### 3. Configure Environment

```bash
cp .env.example .env
# Edit .env with your values
```

### 4. Deploy

```bash
docker compose up --build -d
```

Access: `<url>` (for forwarding mode)

## 📁 Project Structure

- [`components/`](components/) — Source compose components
  - [`base/`](components/base/) — Base <service> configuration
  - [`environments/`](components/environments/) — Environment-specific configurations
  - [`extensions/`](components/extensions/) — Extension components (if present)
- [`build/`](build/) — Generated configurations (auto-generated, ready to deploy)
- [`stackbuilder.toml`](stackbuilder.toml) — Build configuration for stackbuilder

## 🔧 Available Configurations

### Environments

- **forwarding**: <description>
- **letsencrypt**: <description>
- **step-ca**: <description>

### Extensions

- **<ext-name>**: <description>

## 🔧 Environment Variables

### Base Configuration

- `COMPOSE_PROJECT_NAME`: Project name for Docker Compose
- `IMAGE`: Docker image (default: <default>)

### Let's Encrypt Configuration

- `VIRTUAL_PORT`: Port for nginx-proxy (default: <port>)
- `VIRTUAL_HOST`: Domain for nginx-proxy
- `LETSENCRYPT_HOST`: Domain for SSL certificate
- `LETSENCRYPT_EMAIL`: Email for certificate registration

### Step CA Configuration

- <same VIRTUAL_*/LETSENCRYPT_* set + app TLS env vars>

### OIDC Configuration

- `SSO_CLIENT_ID`: OAuth2 client name in kanidm
- `SSO_CLIENT_SECRET`: OAuth2 client secret
- `SSO_AUTHORITY`: Issuer URL (`https://<kanidm-domain>/oauth2/openid/<client-name>`)

### Step CA Trust Configuration

- `STEP_CA_TRUST`: Install the CA bundle into the container (default: true)
- `STEP_CA_TRUST_RESTART`: Restart the service after install (default: true)

## 🌐 Networks

- **forwarding**: `<name>` (internal)
- **letsencrypt**: `letsencrypt-network` (external)
- **step-ca**: `step-ca-network` (external)

## 🔒 Security

⚠️ **Production Checklist:**

- <checklist items>

## 🆘 Troubleshooting

**Build Issues:**
- <items>

**SSL Issues:**
- **Let's Encrypt**: Verify domain DNS and letsencrypt-manager
- **Step CA**: Check step-ca-manager and virtual network config

## 📝 Notes

- The `build/` directory is automatically generated and should not be edited manually
- Environment variables in generated files use `$VARIABLE_NAME` format for proper interpolation
- Each generated configuration includes a complete `docker-compose.yml` and `.env.example`
- Use `sb build` to regenerate all configurations after modifying components
````

## Rules recap (outside the template blocks)

- Emoji on every heading; 100% English; every command fenced with a language tag.
- Reuse `modules/ssl-automation/{letsencrypt-manager,step-ca-manager}/README.md`
  verbatim when linking modules — never paraphrase them.
- Omit sections for features the stack does not have (e.g. no Extensions
  section when there are none) but keep the ORDER of remaining sections.
