# Proxmox CI: CI Environment for LXC Container Automation

## Overview

Proxmox CI is an automation environment for provisioning and orchestrating Linux containers (LXC) in Proxmox VE.  

It is designed as a self-managed system, supporting continuous adaptation and extension by maintaining provisioning, configuration, and deployment processes within an integrated, version-controlled Git environment.  

The architecture separates infrastructure provisioning, system configuration, and runtime execution into modular stages to enable reproducible Proxmox VE container builds.


![Proxmox CI Deployment](docs/redeploy.png)

## Core Components

### Layered Structure

- **init:** Loads centralized configuration.
- **base:** Provisions default base container.
- **share:** Configures network shares for integration access.
- **config:** Applies configuration and runtime setup.

## Continuous Self-Management

- **Container Configuration:** Centralized container configuration via `config.env`.
- **Container Provisioning:** Managed via Proxmox API and Ansible.
- **Configuration Management:** Ansible for provisioning, Chef (Cinc) for configuration.
- **Local Development:** Docker-based environment for local testing.
- **Repository Management:** Automated API calls to the integrated Git service.
- **Network Shares:** Provisioned for extendable shared workspace access.

## Project Structure

```
.
├── .gitea/workflows/       # Pipeline definitions
├── config/                 # Configuration
│   ├── attributes/
│   ├── recipes/
│   └── templates/
├── default/                # Base container configuration
│   ├── .gitea/workflows/
│   ├── roles/setup/
│   └── default.yml
├── local/                  # Local development
│   ├── Dockerfile
│   └── run.sh
├── share/                  # Network share
│   ├── attributes/
│   ├── recipes/
│   └── templates/
└── config.env              # Container configuration
```
