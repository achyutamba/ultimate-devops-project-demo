# Architecture (Extended)

This extended architecture document provides deeper detail into components, data flows, networking, and deployment considerations.

## Component responsibilities

- ingress / frontend-proxy
  - Terminate TLS, route external traffic to services in `frontend` namespace
  - Implement WAF rules when using Application Gateway or Azure Front Door

- frontend
  - Static UI + server-side rendering (if applicable). Calls backend APIs.

- backend microservices (cart, checkout, productcatalog, payment, recommendation, shipping, etc.)
  - Small stateless services exposing HTTP endpoints and OTEL metrics/traces
  - Some services publish to Event Hubs for async processing

- valkey / redis-backed components
  - Provide caching and feature-flag style storage where applicable

- data plane
  - PostgreSQL for relational storage; connection restricted to app subnet and private endpoint
  - Redis used for caching, session and short-lived key-value storage
  - Event Hubs for asynchronous processing and high throughput messaging

## Networking and connectivity

- VNet and subnets
  - VNet: 10.0.0.0/16
  - AKS subnet: 10.0.1.0/24
  - AppGW subnet: 10.0.2.0/24
  - Database subnet: 10.0.3.0/24

- Private endpoints
  - Use private endpoints for Postgres and Storage where possible to keep traffic within Azure backbone

- NSGs and Network Policies
  - NSGs at subnet-level limit traffic from outside the VNet
  - Kubernetes NetworkPolicies apply at pod level to restrict cross-pod communications

## Identity and access

- Terraform-managed service principals / managed identities for automation
- AKS uses managed identities for cluster components (kubelet, cloud provider)
- CI/CD uses a service principal with minimal RBAC to deploy Helm releases and update resources in resource groups created for the environment

## Observability pipeline

- Applications -> OTel SDK -> OTel Collector
- OTel Collector does batching, sampling, and export to Prometheus/Azure Monitor
- Prometheus scrapes app endpoints and collector metrics for alerting
- Grafana displays dashboards sourced from Prometheus and Log Analytics

## High-level metrics and logging decisions

- Short term/operational metrics: Prometheus (1-2 week retention)
- Long-term analytics and correlation: Azure Monitor (Log Analytics)
- Traces: sampled traces to OTel + Azure Monitor/other backends

## Scalability and HA

- AKS node pools: system pool for infra pods, user pools for workloads with autoscaling
- Use cluster autoscaler and HPA
- Postgres: dev uses lower SKU; for staging/prod choose higher availability SKUs

## Diagram (PlantUML suggestion)

You can create a PlantUML diagram with the elements above. Example snippet for `docs/diagrams/architecture.puml`:

```
@startuml
actor User
node "Ingress" as IG
node "AKS Cluster" as AKS
database "Postgres" as PG
cloud "Event Hubs" as EH
User -> IG -> AKS
AKS -> PG
AKS -> EH
@enduml
```

This file is an extended companion to `ARCHITECTURE.md` and `README.md` and intended for teams that want deeper design notes.
