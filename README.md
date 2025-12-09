**Note:** This project is a fork of `opentelemetry-demo`. Thanks to the OpenTelemetry team and contributors for opensourcing this wonderful demo project.

<!-- markdownlint-disable-next-line -->
# <img src="https://opentelemetry.io/img/logos/opentelemetry-logo-nav.png" alt="OTel logo" width="45"> OpenTelemetry Demo - Azure Enterprise Edition

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg?color=red)](https://github.com/open-telemetry/opentelemetry-demo/blob/main/LICENSE)

## 🚀 Enterprise-Grade Azure Implementation

This repository extends the OpenTelemetry Astronomy Shop demo with **production-ready Azure infrastructure, SOC 2 compliant CI/CD pipelines, and enterprise security features**.

### ✨ What's New in This Fork

- **☁️ Complete Azure Infrastructure** - Multi-environment Terraform modules (Dev/Staging/Prod)
- **🔐 SOC 2 Compliant CI/CD** - OIDC authentication, SAST, SCA, container scanning, IaC validation
- **🛡️ Security First** - Trivy, SonarQube, OWASP Dependency Check, Checkov integration
- **📦 GitOps Ready** - ArgoCD configuration with HA setup for production
- **🎯 Production-Grade** - Helm charts, multi-zone AKS, automated rollback, observability stack
- **📊 Cost Optimized** - Environment-specific resource tiers, autoscaling, budget controls
- **🔍 Audit & Compliance** - Comprehensive logging, 2-year retention, immutable audit trails

## Welcome to the OpenTelemetry Astronomy Shop Demo

This repository contains the OpenTelemetry Astronomy Shop, a microservice-based distributed system demonstrating OpenTelemetry implementation in a production-like Azure environment.

### Key Features

- **18 Microservices** across 10+ programming languages (.NET, Go, Python, Java, Node.js, Rust, C++, Ruby, PHP, Kotlin)
- **Azure Kubernetes Service (AKS)** with multi-zone deployment
- **Azure Container Registry (ACR)** with image signing and SBOM generation
- **Azure PostgreSQL Flexible Server** with HA configuration
- **Azure Cache for Redis** with replication
- **Azure Event Hubs** for event streaming
- **Azure Monitor** + OpenTelemetry for complete observability
- **Network Policies** with Calico for zero-trust security
- **Automated Blue-Green & Canary Deployments**

## 📚 Quick Start

### Azure Deployment (Recommended)

Get started with the production-ready Azure infrastructure:

```bash
# 1. Clone the repository
git clone https://github.com/achyutamba/ultimate-devops-project-demo.git
cd ultimate-devops-project-demo

# 2. Deploy infrastructure with Terraform
cd terraform/environments/dev
terraform init
terraform plan
terraform apply

# 3. Deploy applications with Helm
cd ../../../helm-charts
helm install otel-demo ./otel-demo \
  --namespace otel-demo-dev \
  --values ./otel-demo/values-dev.yaml

# 4. Access the application
kubectl port-forward -n otel-demo-dev svc/frontend 8080:8080
```

Visit http://localhost:8080 to see the Astronomy Shop.

### Local Development with Docker

```bash
# Quick start with Docker Compose
docker-compose up -d

# Access the application
open http://localhost:8080
```

## 📖 Comprehensive Documentation

Explore our detailed guides for implementing enterprise-grade Azure infrastructure:

### Core Architecture
- **[Architecture Overview](docs/ARCHITECTURE.md)** - Complete system design, network topology, security layers
- **[Extended Architecture](docs/ARCHITECTURE_EXTENDED.md)** - Deep dive into microservices patterns

### Infrastructure & IaC
- **[Terraform Guide](docs/TERRAFORM.md)** - Multi-environment infrastructure provisioning
- **[Terraform Extended](docs/TERRAFORM_EXTENDED.md)** - Advanced patterns, state management, modules

### CI/CD & GitOps
- **[CI/CD Pipelines](docs/CICD-PIPELINES.md)** - Azure DevOps pipeline architecture
- **[CI/CD Extended](docs/CI_CD_EXTENDED.md)** - SOC 2 compliance, security scanning, OIDC federation
- **[GitOps with ArgoCD](docs/GITOPS_ARGOCD.md)** - Declarative deployments, sync policies
- **[ArgoCD Quickstart](docs/ARGOCD_PIPELINE_QUICKSTART.md)** - Get started in 15 minutes

### Kubernetes & Helm
- **[Helm & Kubernetes](docs/HELM-KUBERNETES.md)** - Chart structure, multi-environment values
- **[Helm Extended](docs/HELM_K8S_EXTENDED.md)** - Advanced Helm patterns, HPA, Network Policies

### Security & Compliance
- **[Security Extended](docs/SECURITY_EXTENDED.md)** - RBAC, Network Policies, secrets management
- **SOC 2 CI/CD Security** - SAST, SCA, Trivy, Checkov integration (see [CI/CD Extended](docs/CI_CD_EXTENDED.md))

### Operations & Monitoring
- **[Observability Extended](docs/OBSERVABILITY_EXTENDED.md)** - OpenTelemetry, Prometheus, Grafana, Jaeger
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Realtime Troubleshooting](docs/REALTIME_TROUBLESHOOTING.md)** - Production debugging techniques
- **[Deployment Runbook](docs/DEPLOYMENT_RUNBOOK.md)** - Step-by-step deployment procedures

### Quick References
- **[Quickstart Guide](docs/QUICKSTART.md)** - Get running in 10 minutes
- **[Azure Implementation Guide](AZURE-IMPLEMENTATION-GUIDE.md)** - Complete setup walkthrough
- **[Production Comparison](REAL-WORLD-PRODUCTION-COMPARISON.md)** - Dev vs Prod configurations

## 🏗️ Architecture Highlights

### Multi-Environment Strategy
```
Dev Environment          Staging Environment       Production Environment
├── AKS: 2-4 nodes      ├── AKS: 3-8 nodes       ├── AKS: 5-20 nodes (multi-zone)
├── PostgreSQL: B1ms    ├── PostgreSQL: D2s      ├── PostgreSQL: D4s + HA
├── Redis: Basic C0     ├── Redis: Standard C1   ├── Redis: Premium P1
└── Cost: ~$355/mo      └── Cost: ~$1,095/mo     └── Cost: ~$6,250/mo
```

### Security Scanning Pipeline
```
Build → SAST (SonarQube) → SCA (OWASP) → Trivy (Container) → Checkov (IaC) → Sign & Push → Deploy
```

### Observability Stack
```
Application → OTel Collector → Prometheus/Jaeger/Azure Monitor → Grafana Dashboards
```

## 🛠️ Technology Stack

| Layer | Technologies |
|-------|-------------|
| **Cloud Platform** | Azure (AKS, ACR, PostgreSQL, Redis, Event Hubs, Key Vault) |
| **Infrastructure as Code** | Terraform, Terragrunt, Azure CLI |
| **Container Orchestration** | Kubernetes 1.28+, Helm 3 |
| **CI/CD** | Azure DevOps, GitHub Actions, ArgoCD |
| **Security Scanning** | SonarQube, Trivy, OWASP Dependency Check, Checkov, Cosign |
| **Observability** | OpenTelemetry, Prometheus, Grafana, Jaeger, Azure Monitor |
| **Languages** | .NET, Go, Python, Java, Node.js, Rust, C++, Ruby, PHP, Kotlin |

## 💰 Cost Management

Monthly infrastructure costs by environment:

| Environment | Resources | Monthly Cost |
|-------------|-----------|--------------|
| **Dev** | Basic tier, 2-4 nodes | ~$355 |
| **Staging** | Standard tier, 3-8 nodes | ~$1,095 |
| **Production** | Premium/HA tier, 5-20 nodes | ~$6,250 |

Includes cost optimization features:
- Auto-shutdown for non-prod environments
- Spot instances for Dev/Staging
- Resource right-sizing recommendations
- Tag-based cost allocation

## 🔐 SOC 2 Compliance Features

- ✅ OIDC federation (no long-lived credentials)
- ✅ Multi-stage security scanning (SAST/SCA/Container/IaC)
- ✅ Artifact signing with Cosign + SBOM generation
- ✅ Immutable audit logs (2-year retention)
- ✅ RBAC with least privilege
- ✅ Network policies (zero-trust)
- ✅ Automated compliance reporting

## 🚀 CI/CD Pipeline Features

- **Multi-Environment Deployments** (Dev/Staging/Prod)
- **Security Scanning** at every stage
- **Automated Rollback** on health check failures
- **Blue-Green & Canary Deployments**
- **GitOps with ArgoCD** for declarative infrastructure
- **Slack/Teams Notifications**
- **DORA Metrics Tracking**

## 📊 Monitoring & Observability

- **Distributed Tracing** with OpenTelemetry & Jaeger
- **Metrics Collection** with Prometheus
- **Visualization** with Grafana dashboards
- **Azure Monitor Integration** for platform insights
- **Centralized Logging** with Log Analytics
- **Custom Alerts** for SLO violations

## 🤝 Contributing

This is a personal fork demonstrating enterprise Azure patterns. Feel free to:
- Fork this repository for your own Azure implementations
- Open issues for bugs or suggestions
- Submit PRs for improvements

For contributing to the upstream OpenTelemetry Demo project, visit:
- [OpenTelemetry Demo Repository](https://github.com/open-telemetry/opentelemetry-demo)
- [Contributing Guidelines](./CONTRIBUTING.md)

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Special thanks to:
- The [OpenTelemetry](https://opentelemetry.io/) team for the amazing demo project
- All contributors to the upstream [opentelemetry-demo](https://github.com/open-telemetry/opentelemetry-demo) repository
- The Azure and Kubernetes communities for excellent documentation

---

**Original OpenTelemetry Demo:** https://github.com/open-telemetry/opentelemetry-demo  
**Azure Enterprise Fork:** https://github.com/achyutamba/ultimate-devops-project-demo

For questions or feedback, please open an issue in this repository.