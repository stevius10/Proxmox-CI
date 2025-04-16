# Proxmox CI: CI Environment for LXC Container Automation

## Overview

Proxmox CI is an automated GitOps system for provisioning and orchestrating Linux containers (LXC) in Proxmox environments. 

It employs modular orchestration layers to achieve a recursive, self-deploying system. The architecture separates base infrastructure, system configuration, and runtime execution.

![Proxmox CI Deployment](docs/redeploy.png)

## Core Components

### Layered Pipeline Structure

The layered pipeline manages desired state configurations:

- **container-init:** Environment and parameter initialization.
- **container-default:** Base container provisioning.
- **container-configuration:** Service-specific configuration.

## Self-Referential Deployment

The system bootstraps itself recursively:

1. The initial pipeline creates a Proxmox container with an integrated Git platform.
2. The system imports its own codebase for self-management.
3. It establishes the CI structure within the deployed Git service.
4. Configuration references itself, enabling continuous deployment on changes.

This closed deployment loop ensures all changes propagate automatically through the self-hosted infrastructure.

## Technical Implementation

- **Container Provisioning:** Managed via Proxmox API using Ansible modules.
- **Configuration Management:** Dual orchestration with Ansible for provisioning and Chef (Cinc) for application configuration.
- **Repository Management:** Automated via API calls.
- **Local Development:** Docker-based environment for local container testing.

## Project Structure

```
.
├── .gitea/workflows/       # CI pipeline definitions
├── config/                 # Service-specific configuration
│   ├── attributes/         # Chef attributes 
│   ├── recipes/            # Chef implementation recipes
│   └── templates/          # Configuration templates
├── default/                # Base container configuration
│   ├── .gitea/workflows/   # Default container actions
│   ├── roles/setup/        # Ansible roles for base setup
│   └── default.yml         # Ansible playbook
├── local/                  # Development environment
│   ├── Dockerfile          # Container definition
│   └── run.sh              # Development workflow script
└── config.env              # Environment configuration
```
